/******************************************************/
/* Simulator.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/******************************************************/
%RSUSetConstant(Simulator, Simulator__)

/**==================================================**/
/* プロセス実行
/*
/* NOTE: プロセスに登録されているFormula を順次実行
/**==================================================**/
%macro Simulator__RunProcess(i_process_id =);
	%&RSULogger.PutSubsection(Running process "&i_process_id."...)
	%if (%&RSUDS.IsDSEmpty(&G_SETTING_CONFIG_DS_SIMULATION.(where = (process_id = "&i_process_id.")))) %then %do;
		%&RSULogger.PutWarning(No task included in the process. Check configuration)
		%return;
	%end;

	%&Utility.ShowDSSingleColumn(ids_source_ds = &G_SETTING_CONFIG_DS_SIMULATION.(where = (process_id = "&i_process_id."))
										, i_variable_def = formula_set_id
										, i_title = [Formula(s) to be executed])
	%ClearPreviousData(i_process_id = &i_process_id.)
	%local _formula_set_id;
	%local _data_index;
	%local _simulation_range;
	%local _dsid_formulas_in_process;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_SIMULATION.(where = (process_id = "&i_process_id."))
										, i_vars = _formula_set_id:formula_set_id
													_data_index:data_index
													_simulation_range:simulation_range
										, ovar_dsid = _dsid_formulas_in_process));
		%RunEachFormulaInProcess(i_formula_set_id = &_formula_set_id.
										, i_data_index = &_data_index.
										, i_simulation_range = &_simulation_range.);
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Faild to run process "&i_process_id.")
			%&RSUDS.TerminateLoop(_dsid_formulas_in_process);
			%return;
		%end;
	%end;
%mend Simulator__RunProcess;

/*---------------------------*/
/* 以前のデータ削除
/*---------------------------*/
%macro ClearPreviousData(i_process_id =);
	%&RSULogger.PutSubsection(Clearing previous data for the process "&i_process_id.")
	%local _formula_set_id;
	%local _dsid_formulas_in_process;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_SIMULATION.(where = (process_id = "&i_process_id."))
										, i_vars = _formula_set_id:formula_set_id
										, ovar_dsid = _dsid_formulas_in_process));
		%ClearEachFormulaDataHelper(i_formula_set_id = &_formula_set_id.)
	%end;
%mend ClearPreviousData;

%macro ClearEachFormulaDataHelper(i_formula_set_id =);
	%&RSULogger.PutNote(Deleting data related to formula "&i_formula_set_id."...)
	%&RSUDS.Delete(%&DataObject.DSVariablePart(i_suffix = &i_formula_set_id.))
	%&RSUDS.Delete(%&FormulaManager.FormulaResult(i_formula_set_id = &i_formula_set_id.))
	%&RSUDS.Delete(%&EnvironmentManager.DSError(i_formula_set_id = &i_formula_set_id.))
	%local _aggr_data_id_output;
	%local _dsid_aggr;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_RESULT_AGGR.(where = (formula_set_id = "&i_formula_set_id."))
										, i_vars = _aggr_data_id_output:data_id_output
										, ovar_dsid = _dsid_aggr));
		%&RSUDS.Delete(%&DataObject.DSVariablePart(i_suffix = &_aggr_data_id_output.))
		%&RSUDS.Delete(%&FormulaManager.FormulaResult(i_formula_set_id = &_aggr_data_id_output.))
		%&RSUDS.Delete(%&EnvironmentManager.DSError(i_formula_set_id = &_aggr_data_id_output.))
	%end;
	%&ReportManager.ClearExcelReport(i_formula_set_id = &i_formula_set_id.)
%mend ClearEachFormulaDataHelper;

/*---------------------------------*/
/* Formula 単体実行
/*
/* NOTE: [Job Flow]
/* NOTE: Formula セット評価
/* NOTE: 結果保存
/* NOTE: 結果の集計
/* NOTE: エクセルレポート作成
/*---------------------------------*/
%macro RunEachFormulaInProcess(i_formula_set_id =
										, i_data_index =
										, i_simulation_range =);
	/* 完全展開レイヤーを生成 */
	%local /readonly _TMP_DS_DIMENSION = %&RSUDS.GetTempDSName(dimension);
	%&Dimension.Construct(i_formula_set_id = &i_formula_set_id.
								, i_data_index = &i_data_index.
								, ods_dimension = &_TMP_DS_DIMENSION.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to expanding formula with full layers.)
		%return;
	%end;
%&RSUError.Stop()
%return;

	/* 数式展開用 */
	%local /readonly _TMP_DS_FORMULA_ADDRESS = %&RSUDS.GetTempDSName(formula_address);
	%&RSUDS.Let(i_query = &_TMP_DS_FULL_LAYER.(keep = address addr_: formula_system_id___)
					, ods_dest_ds = &_TMP_DS_FORMULA_ADDRESS.)
	/* 物理名称に戻すためのマップ */
	%&RSUDS.Move(i_query = &_TMP_DS_FULL_LAYER.
					, ods_dest_ds = WORK.layer_decode_map(drop = addr_: formula_system_id:))
	/* 入力準備 */
	%local /readonly _TMP_DS_VALUE_POOL = %&RSUDS.GetTempDSName(value_pool);
	%local _regex_formula_parsing;
	%local _no_of_input_data;
	%local _regex_parameter_table;
	%&ValuePool.PrepareInput(i_formula_set_id = &i_formula_set_id.
									, ods_value_pool = &_TMP_DS_VALUE_POOL.
									, ovar_regex_formula_parsing = _regex_formula_parsing
									, ovar_no_of_input_data = _no_of_input_data
									, ovar_regex_paramter_table = _regex_parameter_table)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to prepare input data.)
		%return;
	%end;

	/* 評価 */
	%local /readonly _TMP_DS_EXTEDED_LAYER = %&RSUDS.GetTempDSName(full_ext_layer);
	%&FormulaEvaluator.Evaluate(i_formula_set_id = &i_formula_set_id.
										, iods_formula_address = &_TMP_DS_FORMULA_ADDRESS.
										, ids_value_pool = &_TMP_DS_VALUE_POOL.
										, i_regex_formula_parsing = &_regex_formula_parsing.
										, i_no_of_input_data = &_no_of_input_data.
										, i_regex_parameter_table = &_regex_parameter_table.)
	%&RSUDS.Delete(&_TMP_DS_FORMULA_ADDRESS. &_TMP_DS_VALUE_POOL.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to evaluate.)
		%return;
	%end;
	%&LayerManager.Decode(iods_decode_map = WORK.layer_decode_map
								, ids_coded_value = %&DataObject.DSVariablePart(i_suffix = &i_formula_set_id.))
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to decode result data.)
		%return;
	%end;
	/* 結果保存 */
	%StoreResult(i_formula_set_id = &i_formula_set_id.
					, ids_decoded_result = WORK.layer_decode_map)

	/* 付随タスク1 - 集計 */
	%local /readonly _TMP_DS_FORMULA_RESULT_AGGR = %&RSUDS.GetTempDSName(formula_rslt_aggr);
	%&ResultAggregator.AggregateResult(i_formula_set_id = &i_formula_set_id.
												, ids_formula_result = WORK.layer_decode_map
												, ods_aggregated_result = WORK.tmp_aggregated_result)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to aggregating result of formula. Processs terminated.)
		%return;
	%end;

	/* 結果保存 */
	%if (%&RSUDS.Exists(WORK.tmp_aggregated_result)) %then %do;
		%StoreResult(i_formula_set_id = &i_formula_set_id._Aggr
						, ids_decoded_result = WORK.tmp_aggregated_result)
		%&RSUDS.Delete(WORK.tmp_aggregated_result)
	%end;
	
	/* 付随タスク2 - エクセルレポート */
	%if (%&RSUDS.IsDSEmpty(&G_SETTING_CONFIG_DS_EXCEL_REPORT.(where = (formula_set_id = "&i_formula_set_id.")))) %then %do;
		%&RSULogger.PutInfo(No excel reporting tasks follows formula evaluation of "&i_formula_set_id.".)
		%goto _skip_generating_excel_report;
	%end;
	%&ReportManager.GenerateExcelReport(i_formula_set_id = &i_formula_set_id.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to create excel report of formula. Processs terminated.)
		%return;
	%end;

	%&RSUDS.Delete(WORK.layer_decode_map)
%_skip_generating_excel_report:
%mend RunEachFormulaInProcess;

/*-----------------------------------------*/
/* 結果保存
/*
/* NOTE: フォーマット済み結果を保存
/* NOTE: QuickView 用にアップロード
/*-----------------------------------------*/
%macro StoreResult(i_formula_set_id =
						, ids_decoded_result =);
	%&RSULogger.PutSubsection(Result storing: "&i_formula_set_id."...)
	%&ReportManager.SaveFormattedResult(ids_raw_result = &ids_decoded_result.
													, ids_report_info_ds = %&ReportManager.DSReportInfo(i_formula_set_id = &i_formula_set_id.)
													, i_save_data_as = %&FormulaManager.FormulaResult(i_formula_set_id = &i_formula_set_id.))
/*	%&LASRUpldr.Upload(i_library_full_name = &G_LASR_QV_LIBRARY_FULL_NAME.
							, i_lasr_library = &G_CONST_LIB_LASR_QV.
							, ids_source_ds = %&FormulaManager.FormulaResult(i_formula_id = &i_formula_id.)
							, i_dest_location = &G_LASR_QV_DS_LOCATION.
							, i_is_append = %&RSUBool.False)*/
%mend StoreResult;

%macro Simulator__InsertModelEvalProc();
	/* 一行目に Model Evaluation 処理を挿入 */
	data &G_SETTING_CONFIG_DS_SIMULATION.;
		if (_N_ = 0) then do;
			set &G_SETTING_CONFIG_DS_SIMULATION.;
		end;
		if (_N_ = 1) then do;
			process_id = 'MODEL_EVALUATION';
			formula_id = 'MODEL_EVALUATION';
			simulation_range = '1';
			description = 'Internal: Model evaluation';
			output;
		end;
		set &G_SETTING_CONFIG_DS_SIMULATION.;
		output;
	run;
	quit;
%mend Simulator__InsertModelEvalProc;
