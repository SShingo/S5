/***********************************************************/
/* ConfigurationTables.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***********************************************************/
%RSUSetConstant(ConfigurationTable, ConfTbl__)
%RSUSetConstant(G_CONST_DS_EXTERNAL_DATA_LIST, &G_CONST_LIB_WORK..CONFIG_EXTERNAL_DATA_LIST)

/**======================================================**/
/* 初期化
/*
/* NOTE: 全部の設定ファイルを読み込んで L_WORK下にデータセット化
/* NOTE: 以降のプロセスではデータセットを利用
/**======================================================**/
%macro ConfTbl__Create();
	%&RSULogger.PutSubsection(Configuration datasets from excel file)
	%local /readonly _TMP_DS_CONFIG_TABLE_LIST = %&RSUDS.GetTempDSName(configuration_tables);
	%&DataController.LoadExcel(i_excel_file_path = &G_FILE_SYSTEM_SETTING.
										, i_setting_excel_file_path = &G_FILE_SYSTEM_SETTING.
										, i_sheet_name = Config Files
										, ods_output_ds = &_TMP_DS_CONFIG_TABLE_LIST.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUDS.Delete(&_TMP_DS_CONFIG_TABLE_LIST.)
		%&RSUError.Throw(Error occured during loading excel file &G_FILE_SYSTEM_SETTING.)
		%return;
	%end;
	%local /readonly _NO_OF_DATA = %&RSUDS.GetCount(&_TMP_DS_CONFIG_TABLE_LIST.);
	%&RSULogger.PutInfo(&_NO_OF_DATA. configuration will be loaded...)
	%&Utility.ShowDSSingleColumn(ids_source_ds = &_TMP_DS_CONFIG_TABLE_LIST.
										, i_variable_def = sheet_name
										, i_title = [Excel sheets to be read])

	%LoadConfugrationTable(ids_configuration_table_list = &_TMP_DS_CONFIG_TABLE_LIST.)
	%&RSUDS.Delete(&_TMP_DS_CONFIG_TABLE_LIST.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSULogger.PutError(Error occured during loading one of the configuration file)
		%return;
	%end;	
	%ComplementVariableDefinition()
	%EnrichSimulationRange()
	%CreateDataList()
%mend ConfTbl__Create;

%macro LoadConfugrationTable(ids_configuration_table_list =
									, ovar_all_config_loaded =);
	%local _sheet_name;
	%local _macro_variable_name;
	%local _stratum_only;
	%local _dsid_config_file;
	%local _no_of_obs_in_config_table;
	%local _loaded_status_result;
	%local _index_count;
	%local _is_all_loaded;
	%let _is_all_loaded = %&RSUBool.True;
	%do %while(%&RSUDS.ForEach(i_query = &ids_configuration_table_list.
										, i_vars = _sheet_name:sheet_name
													_macro_variable_name:macro_variable
													_stratum_only:stratum_only
										, ovar_dsid = _dsid_config_file));
		%if ((&_stratum_only. ne 1) or %&EnvironmentManager.CheckRunOnStratum()) %then %do;
			%&RSULogger.PutParagraph(%&RSUCounter.Draw(i_max_index = &_NO_OF_DATA., iovar_index = _index_count) Configuration "&_sheet_name." is being loaded and stored as &&&_macro_variable_name....)
			%&DataController.LoadExcel(i_excel_file_path = &G_FILE_APPLICATION_CONFIG.
												, i_setting_excel_file_path = &G_FILE_SYSTEM_SETTING.
												, i_sheet_name = &_sheet_name.
												, ods_output_ds = WORK.tmp_loaded_conf_table)
			%if (%&RSUError.Catch()) %then %do;
				%&RSUDS.TerminateLoop(_dsid_config_file)
				%let _is_all_loaded = %&RSUBool.False;
				%goto _leave_load_config_table;
			%end;
			%else %do;
				%if (%&RSUDS.Exists(WORK.tmp_loaded_conf_table)) %then %do;
					%&Utility.SaveDS(ids_source_ds = WORK.tmp_loaded_conf_table
										, i_save_as = &&&_macro_variable_name.)
					%let _no_of_obs_in_config_table = %&RSUDS.GetCount(&&&_macro_variable_name.);
					%&RSUText.Append(iovar_base = _loaded_status_result
										, i_append_text = &&&_macro_variable_name....OK (&_no_of_obs_in_config_table.)
										, i_delimiter = %str(,))
				%end;
			%end;
		%end;
	%end;
%_leave_load_config_table:

	%&RSULogger.PutBlock([Configuration Table]
								, &_loaded_status_result.)
	%if (not &_is_all_loaded.) %then %do;
		%&RSUError.Throw(Not all configure table loaded.)
		%return;
	%end;
%mend LoadConfugrationTable;

%macro ComplementVariableDefinition();
	%&RSULogger.PutNote(Filling variable name in &G_SETTING_CONFIG_DS_VAR_DEF.)
	data &G_SETTING_CONFIG_DS_VAR_DEF.;
		set &G_SETTING_CONFIG_DS_VAR_DEF. end = eof;
		if (variable_role = "&G_CONST_VAR_ROLE_TIME.") then do;
			variable_name = "&G_CONST_VAR_TIME.";
		end;
		if (variable_role = "&G_CONST_VAR_ROLE_VALUE_VARIABLE.") then do;
			variable_name = "&G_CONST_VAR_VARIABLE_REF_NAME.";
		end;
		output;
		if (eof) then do;
			data_id = "&G_CONST_VPR_FUNC_TIME.";
			variable_role = "&G_CONST_VAR_ROLE_TIME.";
			variable_name = "&G_CONST_VAR_TIME.";
			output;
		end;
	run;
	quit;
	%&RSULogger.PutBlock(&G_CONST_VAR_ROLE_TIME.: &G_CONST_VAR_TIME.
								, &G_CONST_VAR_ROLE_VALUE_VARIABLE.: &G_CONST_VAR_VARIABLE_REF_NAME.)
%mend ComplementVariableDefinition;

%macro EnrichSimulationRange();
	%&RSULogger.PutParagraph(Parsing simulation range in &G_SETTING_CONFIG_DS_SIMULATION.)
	%&RSUDS.ReplaceNullC(iods_input_ds = &G_SETTING_CONFIG_DS_SIMULATION.
								, i_replaced_vars = simulation_range
								, i_replace_value = %&RSUBool.True)
	%&RSUDS.AddSequenceVariable(i_query = &G_SETTING_CONFIG_DS_SIMULATION.
										, i_sequence_variable_name = execution_formula_order) 
	%&CalculationSetting.SubstituteValueTo(iods_formula_definition = &G_SETTING_CONFIG_DS_SIMULATION.
														, i_target_definition = simulation_range)
	proc sort data = &G_SETTING_CONFIG_DS_SIMULATION. out = &G_SETTING_CONFIG_DS_SIMULATION.(drop = execution_formula_order);
		by
			execution_formula_order
		;
	run;
	quit;
%mend EnrichSimulationRange;

%macro CreateDataList();
	%&RSULogger.PutParagraph(Add data "Time" information to configuration table)
	data &G_CONST_DS_EXTERNAL_DATA_LIST.;
		set &G_SETTING_CONFIG_DS_LOADING_DATA.(keep = data_id ref_function_name) end = eof;
		attrib
			data_index length = $&G_CONST_VAR_LEN_DATA.;
		;
		data_index = put(_N_, HEX&G_CONST_VAR_LEN_DATA..);
		output;
		if (eof) then do;
			data_id = "&G_CONST_VPR_FUNC_TIME.";
			ref_function_name = "&G_CONST_VPR_FUNC_TIME.";
			data_index = put(_N_ + 1, HEX&G_CONST_VAR_LEN_DATA..);
			output;
		end;
	run;
	quit;

	proc sort data = &G_SETTING_CONFIG_DS_FORMULA_EVAL.;
		by
			formula_set_id
		;
	run;
	quit;
	data &G_SETTING_CONFIG_DS_FORMULA_EVAL.;
		set &G_SETTING_CONFIG_DS_FORMULA_EVAL.;
		by
			formula_set_id
		;
		output;
		if (last.formula_set_id) then do;
			data_id = "&G_CONST_VPR_FUNC_TIME.";
			formula_system_id_variable = '';
			output;
		end;
	run;
	quit;
%mend CreateDataList;

/**=============================================**/
/* シミュレーションに向けてConfiguration を設定
/**=============================================**/
%macro ConfTbl__PreparaForSimuation();
	%&RSULogger.PutSection(Configuration for simulation)
	%local /readonly _TMP_DS_DATA_ID = %&RSUDS.GetTempDSName(data_id);
	data &_TMP_DS_DATA_ID.;
		set &G_CONST_DS_EXTERNAL_DATA_LIST.(keep = data_id data_index);
		attrib
			data_index_in length = $2.
			data_index_out length = $2.
			formula_set_id length = $18.
		;
		data_index_in = data_index;
		data_index_out = data_index;
		formula_set_id = data_id;
	run;
	quit;

	data &G_SETTING_CONFIG_DS_FORMULA_EVAL.(drop = _rc);
		if (_N_ = 0) then do;
			set &_TMP_DS_DATA_ID.;
		end;
		set &G_SETTING_CONFIG_DS_FORMULA_EVAL.;
		if (_N_ = 1) then do;
			declare hash hh_data_index_in(dataset: "&_TMP_DS_DATA_ID.");
			_rc = hh_data_index_in.definekey('data_id');
			_rc = hh_data_index_in.definedata('data_index_in');
			_rc = hh_data_index_in.definedone();
			declare hash hh_data_index_out(dataset: "&_TMP_DS_DATA_ID.");
			_rc = hh_data_index_out.definekey('formula_set_id');
			_rc = hh_data_index_out.definedata('data_index_out');
			_rc = hh_data_index_out.definedone();
		end;
		_rc = hh_data_index_in.find();
		_rc = hh_data_index_out.find();
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_DATA_ID.)

	data &_TMP_DS_DATA_ID.;
		set &G_CONST_DS_EXTERNAL_DATA_LIST.(keep = data_id data_index rename = data_id = data_id_output);
		attrib
			data_index_in length = $2.
			data_index_out length = $2.
			formula_set_id length = $18.
		;
		data_index_in = data_index;
		data_index_out = data_index;
		formula_set_id = data_id_output;
	run;
	quit;

	data &G_SETTING_CONFIG_DS_RESULT_AGGR.(drop = _rc);
		if (_N_ = 0) then do;
			set &_TMP_DS_DATA_ID.;
		end;
		set &G_SETTING_CONFIG_DS_RESULT_AGGR.;
		if (_N_ = 1) then do;
			declare hash hh_data_index_in(dataset: "&_TMP_DS_DATA_ID.");
			_rc = hh_data_index_in.definekey('formula_set_id');
			_rc = hh_data_index_in.definedata('data_index_in');
			_rc = hh_data_index_in.definedone();
			declare hash hh_data_index_out(dataset: "&_TMP_DS_DATA_ID.");
			_rc = hh_data_index_out.definekey('data_id_output');
			_rc = hh_data_index_out.definedata('data_index_out');
			_rc = hh_data_index_out.definedone();
		end;
		_rc = hh_data_index_in.find();
		_rc = hh_data_index_out.find();
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_DATA_ID.)

	data &_TMP_DS_DATA_ID.;
		set &G_CONST_DS_EXTERNAL_DATA_LIST.(keep = data_id data_index rename = data_id = formula_set_id);
	run;
	quit;

	data &G_SETTING_CONFIG_DS_SIMULATION.(drop = _rc);
		if (_N_ = 0) then do;
			set &_TMP_DS_DATA_ID.;
		end;
		set &G_SETTING_CONFIG_DS_SIMULATION.;
		if (_N_ = 1) then do;
			declare hash hh_data_index(dataset: "&_TMP_DS_DATA_ID.");
			_rc = hh_data_index.definekey('formula_set_id');
			_rc = hh_data_index.definedata('data_index');
			_rc = hh_data_index.definedone();
		end;
		_rc = hh_data_index.find();
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_DATA_ID.)
%mend ConfTbl__PreparaForSimuation;