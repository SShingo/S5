/***********************************************************/
/* WorkflowModelManagement.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***********************************************************/
%RSUSetConstant(WFModelManagement, WFModelMgr__)

/***************************************************/
/* 事前処理
/***************************************************/
%macro WFModelMgr__PrepareData(i_user_id =
										, i_cycle_id =
										, i_process_name =
										, i_fa_id =
										, i_host =
										, i_port =
										, i_tgt_ticket =
										, i_password =);
	%&RSULogger.PutSection(Initializing and Data preparation)
	%local /readonly _TIMER_TASK = %&RSUTimer.Create;

	%&Process.DoPreprocess()
	%if (%&RSUError.Catch()) %then %do;
		%&RSULogger.PutError(Failed to finish preprocess.)
		%goto _skip_prepare_data;
	%end;
	%&_TIMER_TASK.Lap;

	/* モデル読み込み */
	%&ModelManager.LoadModelFromExcel(iods_model_definition = WORK.DUMMY
												, ods_output_ds = WORK.tmp_raw_model)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load model definition. Process terminated. Check input data.
		%goto _skip_prepare_data;
	%end;
	%&_TIMER_TASK.Lap;

	%&FormulaManager.MergeModelAndFormula(iods_formula_definition = WORK.tmp_raw_formula
													, ids_model_definition = WORK.tmp_raw_model)
	/* シミュレーションプロセス修正 */
	%&Simulator.InsertModelEvalProc()
	/* モデル評価設定 */
	%&FormulaEvaluator.ConfigFormulaEvaluation()

	/* Formula 定義 → レポート情報分離 */
	%&ReportManager.SliceReportInfo(iods_formula_definition = WORK.tmp_raw_formula)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to save report information of formula. Process terminated. Check input data.
		%goto _skip_prepare_data;
	%end;

	/* Formula 定義保存 */
	%&FormulaManager.SaveFormulaDefinition(iods_formula_definition = WORK.tmp_raw_formula)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to save formula(s). Process terminated. Check input data.)
		%goto _skip_prepare_data;
	%end;

	/* レイヤー構造解析 */
	%&LayerManager.ConfigureLayerStructure()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to configure layer structure. Process terminated.)
		%goto _skip_prepare_data;
	%end;

	/* Formulaで参照しているリスクファクターリスト */
	%&ScenarioManager.ExtractRiskFactors(ids_formula_definition = WORK.tmp_raw_formula
													, ods_risk_factors = WORK.tmp_referred_risk_factors)
	%&RSUDS.Delete(WORK.tmp_raw_formula)
	/* 計算設定で指定されているシナリオリスト */
	%&ScenarioManager.LoadScenarioSetting(ods_used_scenario_list = WORK.tmp_scenarios_in_setting)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load scenario setting file)
		%goto _skip_prepare_data;
	%end;
	%if (%&RSUDS.Exists(WORK.tmp_scenarios_in_setting)) %then %do;
		/* シナリオ読み込み */
		%&ScenarioManager.CreateDSFromRSM(ids_scenario_setting = WORK.tmp_scenarios_in_setting
													, i_fa_id = &i_fa_id.
													, i_host = &i_host.
													, i_port = &i_port.
													, i_ticket = &i_tgt_ticket.
													, i_user_id = &i_user_id.
													, i_password = &i_password.)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to Retrieving sceario data from RSM. Check input data.)
			%goto _skip_prepare_data;
		%end;

		%&_TIMER_TASK.Lap;
	%end;

	/* 外部データ読み込み */
	%if (not %&RSUDS.IsDSEmpty(&G_SETTING_CONFIG_DS_LOADING_DATA.)) %then %do;
		%&ExternalValueLoader.LoadFile()
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to create value pool(s). Process terminated. Check input data.
			%goto _skip_prepare_data;
		%end;
		
		%&_TIMER_TASK.Lap;
	%end;
	%if (%&RSUDS.Exists(WORK.tmp_scenarios_in_setting)) %then %do;
		%&ScenarioManager.CheckScenario(ids_used_scenario_list = WORK.tmp_scenarios_in_setting
												, ids_referred_risk_factors = WORK.tmp_referred_risk_factors)
		%&ScenarioManager.Trim()
	%end;
	%&RSUDS.Delete(WORK.tmp_scenarios_in_setting WORK.tmp_referred_risk_factors)

	/* 包括的時間軸作成 */
	%&TimeAxis.Create()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to create time axis. Process terminated. Check input data.
		%goto _skip_prepare_data;
	%end;

	%&_TIMER_TASK.Lap;

	%&ModelManager.MakeMdlUpdateActionTbl(i_cycle_id = &i_cycle_id
													, i_cycle_name =
													, i_user_id = &i_user_id.);
%_skip_prepare_data:
	%&RSUClass.Dispose(_TIMER_TASK);
%mend WFModelMgr__PrepareData;

/****************************************************/
/* Process実行
/****************************************************/
%macro WFModelMgr__RunModel(i_task_no =
									, i_task_title =
									, i_process_id =);
	%&RSULogger.PutSection(Task #&i_task_no.: &i_task_title.)
	%local /readonly _TIMER_TASK = %&RSUTimer.Create;

	%&RSULib.ClearLib(WORK)
	%&Simulator.RunProcess(i_process_id = MODEL_EVALUATION)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to run process for workflow process "&i_workflow_status.")
	%end;

	%&RSUClass.Dispose(_TIMER_TASK)
%mend WFModelMgr__RunModel;

/***************************************************/
/* 事後処理
/***************************************************/
%macro WFModelMgr__Close(i_task_no =
								, i_user_id =
								, i_cycle_id =
								, i_cycle_name =
								, i_action =);
	%&RSULogger.PutSection(Task #&i_task_no.: Closing Process "&i_cycle_id.")
	%local /readonly _TIMER_TASK = %&RSUTimer.Create;
	%if (&i_action. = 1) %then %do;
		%&ModelManager.AppendToDM(i_overwrite = %&RSUBool.False)
	%end;
	%else %if (&i_action. = 2) %then %do;
		%&ModelManager.AppendToDM(i_overwrite = %&RSUBool.True)
	%end;
	%else %do;
		%&RSULogger.PutInfo(Do nothing)
	%end;
	%&RunHistory.Finish(i_cycle_id = &i_cycle_id.)
	%&EnvironmentManager.DeassignLibraries()

	%&RSUClass.Dispose(_TIMER_TASK)
%mend WFModelMgr__Close;
