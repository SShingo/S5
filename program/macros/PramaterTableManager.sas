/***************************************************************/
/* ParameterTableManager.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: パラメータテーブルはすべてを1つのテーブルに保持
/* NOTE: table_name | param_key | param_value
/* NOTE: fcmp関数の "ParameterTable(table_name, param_key)" によって値を取得
/***************************************************************/
%RSUSetConstant(ParameterTableManager, ParamTblMgr__)

/**========================================**/
/* パラメータテーブル作成
/**========================================**/
%macro ParamTblMgr__CreateDSFromExcel();
	%if (%&RSUDS.IsDSEmpty(&G_SETTING_CONFIG_DS_PARAM_TABLE.)) %then %do;
		%&RSULogger.PutInfo(No parameter table is loaded)
	%end;
	%&RSULogger.PutSubsection(Parameter table loading...)
	%local _directory;
	%local _index_directory;
	%do %while(%&RSUUtil.ForEach(i_items = &G_DIR_USER_DATA_RSLT_DIR2_PREDEF. &G_DIR_USER_DATA_RSLT_DIR1_STG.
										, ovar_item = _directory
										, iovar_index = _index_directory));
		%&RSULogger.PutNote(Searching loading data in "&_directory." and Loading data.)
		%ConstructLoaderConfigDSInDir(ids_data_loading_config = &G_SETTING_CONFIG_DS_PARAM_TABLE.
												, i_input_dir = &_directory.
												, ods_data_loading_control_in_dir = WORK.tmp_data_loading_control_in_dir)
		%if (%&RSUDS.Exists(WORK.tmp_data_loading_control_in_dir)) %then %do;
			%LoadParameterTableData(ids_data_loading_control = WORK.tmp_data_loading_control_in_dir)
		%end;
	%end;
	%if (not %&RSUDS.Exists(&G_CONST_DS_PARAMETER_TABLE.)) %then %do;
		%&RSULogger.PutInfo(No parameter talble found.)
		%return;
	%end;
%mend ParamTblMgr__CreateDSFromExcel;

/*---------------------------------------------------------*/
/* パラメータテーブル読み込み
/*
/* NOTE: 元データは複数のキーカラムがあるが、それらを連結して1つのキーにする
/* NOTE: 例： rating_system_id | rating | PD
/* NOTE: param_key = [rating_system_id][rating], param_value = PD
/*---------------------------------------------------------*/
%macro LoadParameterTableData(ids_data_loading_control =);
	%local /readonly _NO_OF_PARAMETER_TABLES = %&RSUDS.GetCount(&ids_data_loading_control.);
	/* 読み込み */
	%local _table_name;
	%local _excel_file_path;
	%local _excel_sheet_name;
	%local _key_variables;
	%local _value_variable;
	%local _dsid_param_table;
	%local _index_parameter_tables;
	%&RSUDS.Delete(WORK.tmp_full_param_table_in_dir)
	%do %while(%&RSUDS.ForEach(i_query = &ids_data_loading_control.
										, i_vars = _table_name:table_name
													_excel_file_path:excel_file_path
													_excel_sheet_name:excel_sheet_name 
													_key_variables:key_variables 
													_value_variable:value_variable 
										, ovar_dsid = _dsid_param_table));
		%&RSULogger.PutParagraph(%&RSUCounter.Draw(i_max_index = &_NO_OF_PARAMETER_TABLES., iovar_index = _index_parameter_tables) Parameter table &_table_name. is being loaded...)
		%&DataController.LoadExcel(i_excel_file_path = &_excel_file_path.
											, i_setting_excel_file_path = &G_FILE_APPLICATION_CONFIG.
											, i_sheet_name = &_excel_sheet_name.
											, ods_output_ds = WORK.tmp_unit_loaded_data)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUDS.TerminateLoop(_dsid_param_table)
			%goto _leave_load_param_tbl;
		%end;
		%&RSULogger.PutNote(Defining parameter: "&_table_name.")
		%DefineTableKeyValue(iods_input_ds = WORK.tmp_unit_loaded_data
									, i_table_name = &_table_name.
									, i_key_variables = &_key_variables.
									, i_value_variable = &_value_variable.);
		%&RSUDS.Append(iods_base_ds = WORK.tmp_full_param_table_in_dir
							, ids_data_ds = WORK.tmp_unit_loaded_data)
		%&RSUDS.Delete(WORK.tmp_unit_loaded_data)
	%end;
	/* Overwrite */
	%&DataController.Overwrite(iods_base_ds = &G_CONST_DS_PARAMETER_TABLE.
										, ids_data_ds = WORK.tmp_full_param_table_in_dir
										, i_by_variables = table_name param_key)
	%&RSUDS.Delete(WORK.tmp_full_param_table_in_dir)
%_leave_load_param_tbl:
%mend LoadParameterTableData;

%macro DefineTableKeyValue(iods_input_ds =
									, i_table_name =
									, i_key_variables =
									, i_value_variable =);
	%local _key_varirable;
	%local _index_key_variable;
	/* key-value ペア */
	data &iods_input_ds.(keep = value_key &G_CONST_VAR_VALUE. &G_CONST_VAR_TIME.);
		set &iods_input_ds;
		attrib
			_param_key length = $200.
			&G_CONST_VAR_VALUE. length = $100.
			value_key length = $200.
			&G_CONST_VAR_TIME. length = 8.
		;
		&G_CONST_VAR_VALUE. = &i_value_variable.;
		_param_key = '';
	%do %while(%&RSUUtil.ForEach(i_items = &i_key_variables.
										, ovar_item = _key_varirable
										, iovar_index = _index_key_variable));
		_param_key = cats(_param_key, cats('[', &_key_varirable., ']'));
	%end;
		value_key = compress(cats('ParameterTable{', "&i_table_name.,", _param_key, '}'));
	run;
	quit;
	%local /readonly _NO_OF_ELEMENTS_OF_PARAM_TBL = %&RSUDS.GetCount(&iods_input_ds.);
	%&RSULogger.PutBlock(Key variable(s): (&i_key_variables.)
								, Table name: &i_table_name.
								, Keys: &i_key_variables.
								, Value variable: &i_value_variable.
								, # of element(s): &_NO_OF_ELEMENTS_OF_PARAM_TBL.)
%mend DefineTableKeyValue;
