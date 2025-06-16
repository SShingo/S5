/***********************************************************/
/* WorkflowScenarioSimulation.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111%RSUSetConstant(Workflow, Workflow__)
/***********************************************************/
%RSUSetConstant(WFScenarioSimulation, WFScenSim__)

/***************************************************/
/* データ準備
/***************************************************/
%macro WFScenSim__PrepareData(i_user_id =
										, i_process_name =
										, i_cycle_id =
										, i_fa_id =
										, i_host =
										, i_port =
										, i_tgt_ticket =
										, i_password =);
	%&RSULogger.PutSection(Initializing and Data preparation)
	%local /readonly _TIMER_TASK = %&RSUTimer.Create();

	/* 事前処理 */
	%&Process.DoPreprocess()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to complete preprocess.)
		%goto _skip_prepare_data;
	%end;
	%&_TIMER_TASK.Lap()

	/* 外部データ読み込み */
	%&ExternalValueLoader.LoadFile()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to create value pool(s). Process terminated. Check input data.)
		%goto _skip_prepare_data;
	%end;

	%&ExternalValueEncoder.MakeKVP()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to make key-value pair of external data. Process terminated. Check input data.)
		%goto _skip_prepare_data;
	%end;
	%&_TIMER_TASK.Lap()

	/* Formula 読み込み */
	%local /readonly _DS_TMP_FORMULA_DEFINITION = %&RSUDS.GetTempDSName(raw_formula);
	%GenerateFormulaDefinitionDS(ods_formula_definition = &_DS_TMP_FORMULA_DEFINITION.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to generate formula definition dataset. Check input data.)
		%goto _skip_prepare_data;
	%end;
	%&_TIMER_TASK.Lap()

	/* 後処理 */
	%&FormulaManager.PostProcess(iods_formula_def = &_DS_TMP_FORMULA_DEFINITION.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error during post processing formula(s). Process terminated. Check input data.)
		%return;
	%end;

	/* レポート情報部保存 */
	%&ReportManager.SaveReportInfo(iods_formula_definition = &_DS_TMP_FORMULA_DEFINITION.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to save report information of formula. Process terminated. Check input data.)
		%return;
	%end;

	/* 式変形 & 式中のRef収集 */
	%&FormulaEncoder.ReformAndCreateRefVars(iods_formula_def = &_DS_TMP_FORMULA_DEFINITION.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error during encoding formula(s). Process terminated. Check input data.)
		%return;
	%end;

	%&FormulaEncoder.Encode(iods_formula_def = &_DS_TMP_FORMULA_DEFINITION.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error during encoding formula(s). Process terminated. Check input data.)
		%return;
	%end;

	/* Formula 定義保存 */
	%&FormulaManager.SaveFormulaDefinition(iods_formula_definition = &_DS_TMP_FORMULA_DEFINITION.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to save formula(s). Process terminated. Check input data.)
		%return;
	%end;

	/* シナリオ */
	%GenerateScenarioDS(ids_formula_definition = &_DS_TMP_FORMULA_DEFINITION.)
	%&RSUDS.Delete(&_DS_TMP_FORMULA_DEFINITION.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to generate scenario dataset.)
		%goto _skip_prepare_data;
	%end;

	/* パラメータテーブル読み込み */
	%&ParameterTableManager.CreateDSFromExcel()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to create parameter table(s). Process terminated. Check input data.)
		%goto _skip_prepare_data;
	%end;
	%&_TIMER_TASK.Lap()

	/* Configuration */
	%&ConfigurationTable.PreparaForSimuation()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to modify configuration table for simulation. Process terminated. Check input data.)
		%goto _skip_prepare_data;
	%end;

%_skip_prepare_data:
	%&RSUClass.Dispose(_TIMER_TASK);
%mend WFScenSim__PrepareData;

/****************************************************/
/* Process実行
/****************************************************/
%macro WFScenSim__RunProcess(i_workflow_status =);
	%&RSULogger.PutNote(Runing prcess on workflow status "&i_workflow_status.")
	%local /readonly _PROCESS_ID = %&RSUDS.GetValue(i_query = &G_SETTING_CONFIG_DS_STRATUM_WF.(where = (workflow_status = "&i_workflow_status."))
																	, i_variable = process_id);
	%local /readonly _PROCESS_TITLE = %&RSUDS.GetValue(i_query = &G_SETTING_CONFIG_DS_STRATUM_WF.(where = (workflow_status = "&i_workflow_status."))
																	, i_variable = process_title);
	%&RSULogger.PutSection(Simulation: &_PROCESS_TITLE.(&_PROCESS_ID.))
	%local /readonly _TIMER_TASK = %&RSUTimer.Create();

	%&RSULib.ClearLib(WORK)
	%&Simulator.RunProcess(i_process_id = &_PROCESS_ID.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to run process for workflow process "&i_workflow_status.")
	%end;
	%&RSUClass.Dispose(_TIMER_TASK)
%mend WFScenSim__RunProcess;

/***************************************************/
/* 事後処理
/***************************************************/
%macro WFScenSim__Close(i_user_id =
								, i_cycle_id =
								, i_cycle_name =
								, i_keep_in_dm =);
	%&RSULogger.PutSection(Closing Process "&i_cycle_id.")
	%local /readonly _TIMER_TASK = %&RSUTimer.Create();

	%if (&i_keep_in_dm.) %then %do;
		%&ResultDM.AppendResult(i_user_id = &i_user_id
										, i_cycle_id = &i_cycle_id.
										, i_cycle_name = &i_cycle_name.)
	%end;

	%&RunHistory.Finish(i_cycle_id = &i_cycle_id.)
	%&EnvironmentManager.DeassignLibraries()

	%&RSUClass.Dispose(_TIMER_TASK)
%mend WFScenSim__Close;

/*--------------------------*/
/* Formula
/*--------------------------*/
%macro GenerateFormulaDefinitionDS(ods_formula_definition =);
	/* Formula 定義読み込み */
	%local /readonly _DM_TMP_LOADED_FORMULA = %&RSUDS.GetTempDSName(loaded_formula);
	%&FormulaManager.CreateDSFromExcel(ods_raw_formula = &_DM_TMP_LOADED_FORMULA.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to create formula(s). Process terminated. Check input data.)
		%return;
	%end;

	%local /readonly _DS_TMP_MODEL_LIST = %&RSUDS.GetTempDSName(model_list);
	%&ModelManager.ExtractModelsInFormula(ids_formula_definition = &_DM_TMP_LOADED_FORMULA.
													, ods_model_list = &_DS_TMP_MODEL_LIST.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to extracting models used in formula. Process terminated. Check input data.)
		%return;
	%end;
	%&FormulaManager.MinimizeSize(ids_formula_definition = &_DM_TMP_LOADED_FORMULA.
											, ods_formula_def_minimized = &ods_formula_definition.)
	%&FormulaManager.FillNuallValue(iods_formula_definition = &ods_formula_definition.)
	%&RSUDS.Delete(&_DM_TMP_LOADED_FORMULA.)
	%local /readonly _DS_TMP_MODEL_DEFINITION = %&RSUDS.GetTempDSName(model_definition);
	%if (%&RSUDS.Exists(&_DS_TMP_MODEL_LIST.)) %then %do;
		/* モデル読み込み（DM & Excel) */
		%&ModelManager.CreateDSFromDMAndExcel(ids_formula_definition = &ods_formula_definition.
														, ids_model_list = &_DS_TMP_MODEL_LIST.
														, ods_model_definition = &_DS_TMP_MODEL_DEFINITION.)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to extract model definition. Process terminated. Check input data.)
			%return;
		%end;

		%&FormulaManager.MergeModelAndFormula(iods_formula_definition = &ods_formula_definition.
														, ids_model_definition = &_DS_TMP_MODEL_DEFINITION.)

		/* シミュレーションプロセス修正 */
		%&Simulator.InsertModelEvalProc()

		/* モデル評価設定 */
		%&FormulaEvaluator.ConfigFormulaEvaluation()
	%end;
	%&RSUDS.Delete(&_DS_TMP_MODEL_LIST. &_DS_TMP_MODEL_DEFINITION.)
%mend GenerateFormulaDefinitionDS;

%macro GenerateScenarioDS(ids_formula_definition =);
	/* Formulaで参照しているリスクファクターリスト */
	%&RSULogger.PutSubsection(Risk factors in formula)
	%return;
	%local /readonly _DS_TMP_RISK_FACTOR = %&RSUDS.GetTempDSName(risk_factor);
	%&ScenarioManager.ExtractRiskFactors(ids_formula_definition = &ids_formula_definition.
													, ods_risk_factors = &_DS_TMP_RISK_FACTOR.)
	/* 計算設定で指定されているシナリオリスト */
	%local /readonly _DS_TMP_SCENARIO_SETTING = %&RSUDS.GetTempDSName(scenario_setting);
	%&ScenarioManager.LoadScenarioSetting(ods_used_scenario_list = &_DS_TMP_SCENARIO_SETTING.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load scenario setting file)
		%return;
	%end;
	%if (%&RSUDS.Exists(&_DS_TMP_SCENARIO_SETTING.)) %then %do;
		/* シナリオ読み込み */
		%&ScenarioManager.CreateDSFromRSM(ids_scenario_setting = &_DS_TMP_SCENARIO_SETTING.
													, i_fa_id = &i_fa_id.
													, i_host = &i_host.
													, i_port = &i_port.
													, i_ticket = &i_tgt_ticket.
													, i_user_id = &i_user_id.
													, i_password = &i_password.)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to Retrieving sceario data from RSM. Check input data.)
			%return;
		%end;

		%&_timer_task.Lap;
		%&ScenarioManager.CheckScenario(ids_used_scenario_list = &_DS_TMP_SCENARIO_SETTING.
												, ids_referred_risk_factors = &_DS_TMP_RISK_FACTOR.)
		%&ScenarioManager.Trim()
	%end;
	%&RSUDS.Delete(&_DS_TMP_SCENARIO_SETTING. &_DS_TMP_RISK_FACTOR.)
%mend GenerateScenarioDS;