/***************************************************/
/* DataController.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***************************************************/
%RSUSetConstant(DataController, DataCtrl__)

/**==========================================**/
/* AppConfig.xlsxの設定を元にエクセルファイルのデータをロード
/*
/* NOTE: エクセルファイルとシートを指定
/* NOTE: データのスキーマは "#シート名"として AppConfig.xlsxに設定してある前提
/**==========================================**/
%macro DataCtrl__LoadExcel(i_excel_file_path =
									, i_setting_excel_file_path =
									, i_schema_name =
									, i_sheet_name =
									, ods_output_ds =);
	%if (not %&RSUFile.Exists(&i_excel_file_path.)) %then %do;
		%&RSULogger.PutInfo(Excel file &i_excel_file_path. not found)
		%return;
	%end;

	%if (not %&RSUExcel.ContainsSheet(i_file_path = &i_excel_file_path., i_sheet_name = &i_sheet_name.)) %then %do;
		%&RSUError.Throw(Excel sheet "&i_sheet_name." not found in&i_excel_file_path.)
		%return;
	%end;

	%local /readonly _SCHEMA_SHEET_NAME = %&RSUUtil.Choose(%&RSUUtil.IsMacroBlank(i_schema_name), #&i_sheet_name., #&i_schema_name.);
	%&RSULogger.PutBlock(Target excel file
								, Data: "&i_excel_file_path." sheet name: "&i_sheet_name."
								, Schema: "&i_setting_excel_file_path." sheet name: "&_SCHEMA_SHEET_NAME.")
	%&RSUExcel.VerifyContains(i_file_path = &i_setting_excel_file_path.
									, i_sheet_name = &_SCHEMA_SHEET_NAME.)
	%local _tmp_fref_schema_file;
	%let _tmp_fref_schema_file = %&RSUFile.GetFileRef;
	%&RSUExcel.ExportToText(i_file_path =	&i_setting_excel_file_path.
									, i_sheet_name = &_SCHEMA_SHEET_NAME.
									, i_output_fileref =	&_tmp_fref_schema_file.)
	%&RSUDS.LoadExcel(i_file_path = &i_excel_file_path.
							, i_sheet_name = &i_sheet_name.
							, i_schema_file_ref = &_tmp_fref_schema_file.
							, ods_output_ds = &ods_output_ds.)
	%&RSUFile.ClearFileRef(_tmp_fref_schema_file)
	%local /readonly _NO_OF_OBSERVATIONS = %&RSUDS.GetCount(&ods_output_ds.);
	%&RSULogger.PutInfo(&_NO_OF_OBSERVATIONS. observaton(s) loaded)
%mend DataCtrl__LoadExcel;

/*-------------------------------*/
/* ロード設定ファイル構築
/*-------------------------------*/
%macro ConstructLoaderConfigDSInDir(ids_data_loading_config =
												, i_input_dir =
												, ods_data_loading_control_in_dir =);
	%&RSUDS.Delete(&ods_data_loading_control_in_dir.)
	/* エクセルファイル名展開 */
	%ExtendLoadingInfoInFiles(ids_data_loading_config = &ids_data_loading_config.
									, i_input_dir = &i_input_dir.
									, ods_loading_info = WORK.tmp_file_extended_loading_info)
	%if (%&RSUDS.GetCount(WORK.tmp_file_extended_loading_info) = 0) %then %do;
		%&RSUDS.Delete(WORK.tmp_file_extended_loading_info)
		%&RSULogger.PutInfo(No matched excel file in directory "&i_input_dir.".)
		%return;
	%end;
	/* 各ファイルを走査 */
	%&RSUDS.GetUniqueList(i_query = WORK.tmp_file_extended_loading_info(keep = excel_file_path)
								, i_by_variables = excel_file_path
								, ods_output_ds = WORK.tmp_file_list)
	%local /readonly _NO_OF_MATCHED_FILES_IN_DIR = %&RSUDS.GetCount(WORK.tmp_file_list);
	%&RSULogger.PutInfo(&_NO_OF_MATCHED_FILES_IN_DIR. excel file(s) matched in directory "&i_input_dir.".)
	%local _excel_file_path;
	%local _dsid_excel_file;
	%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_file_list
										, i_vars = _excel_file_path:excel_file_path
										, ovar_dsid = _dsid_excel_file));
		%&RSULogger.PutNote(Searching excel sheet in excel file: "&_excel_file_path."...)
		%ConstructLoaderConfigDSInFile(ids_data_loading_config = WORK.tmp_file_extended_loading_info
												, i_input_excel_file_path = &_excel_file_path.
												, ods_data_loading_control_in_file = WORK.tmp_data_loading_control_in_file)
		%if (%&RSUDS.Exists(WORK.tmp_data_loading_control_in_file)) %then %do;
			%&RSUDS.Append(iods_base_ds = &ods_data_loading_control_in_dir.
								, ids_data_ds = WORK.tmp_data_loading_control_in_file)
			%&RSUDS.Delete(WORK.tmp_data_loading_control_in_file)
		%end;
	%end;
	%&RSUDS.Delete(WORK.tmp_file_list WORK.tmp_file_extended_loading_info)
%mend ConstructLoaderConfigDSInDir;

%macro ExtendLoadingInfoInFiles(ids_data_loading_config =
										, i_input_dir =
										, ods_loading_info =);
	%&RSUDir.GetContents(i_dir_path = &i_input_dir.
								, ods_output_ds = WORK.tmp_matched_excel_files_in_dir
								, i_content_type = %&RSUFileType.File)
	data WORK.tmp_matched_excel_files_in_dir;
		set WORK.tmp_matched_excel_files_in_dir;
		rename
			_entry_full_path = excel_file_path
			_entry_name = excel_file_name;
		;
		keep
			_entry_full_path
			_entry_name
		;
	run;
	quit;
	%&RSUDS.CrossJoin(ids_lhs_ds = WORK.tmp_matched_excel_files_in_dir
							, ids_rhs_ds = &ids_data_loading_config.)
	/* 正規表現に合致するものを残す */
	data &ods_loading_info.(drop = _:);
		set WORK.tmp_matched_excel_files_in_dir;
		_regex_excel_file_name = prxparse(cats('/', excel_file_name_regex, '/o'));
		if (prxmatch(_regex_excel_file_name, trim(excel_file_name))) then do;
			output;
		end;
		call prxfree(_regex_excel_file_name);
	run;
	quit;
	%&RSUDS.Delete(WORK.tmp_matched_excel_files_in_dir)
%mend ExtendLoadingInfoInFiles;

%macro ConstructLoaderConfigDSInFile(ids_data_loading_config =
												, i_input_excel_file_path =
												, ods_data_loading_control_in_file =);
	%&RSUDebug.PutFootprint(ds config0)
	%local /readonly _SHEETS_IN_EXCEL = %&RSUExcel.GetSheets(i_file_path = &i_input_excel_file_path.);
	%&RSUDebug.PutFootprint(ds config1)
	%local /readonly _TMP_DS_EXCEL_SHEETS = %&RSUDS.GetTempDSName(excel_sheets);
	%&RSUArray.ExportToDS(ivar_array = _SHEETS_IN_EXCEL
								, ods_output_ds = &_TMP_DS_EXCEL_SHEETS.)
	%&RSUDebug.PutFootprint(ds config2)
	data &_TMP_DS_EXCEL_SHEETS.;
		set &_TMP_DS_EXCEL_SHEETS.;
		attrib
			excel_file_path length = $1000.
		;
		excel_file_path = "&i_input_excel_file_path.";
		rename
			value = excel_sheet_name
		;
	run;
	%&RSUDS.InnerJoin(ids_lhs_ds = &_TMP_DS_EXCEL_SHEETS.
							, ids_rhs_ds = &ids_data_loading_config.
							, i_conditions = excel_file_path:excel_file_path
							, ods_output_ds = &ods_data_loading_control_in_file.)
	%&RSUDS.Delete(&_TMP_DS_EXCEL_SHEETS.)
	%&RSUDebug.PutFootprint(ds config3)
	/* 正規表現に合致するものを残す */
	data &ods_data_loading_control_in_file.(drop = _:);
		set &ods_data_loading_control_in_file.;
		_regex_excel_file_name = prxparse(cats('/', excel_sheet_name_regex, '/io'));
		if (prxmatch(_regex_excel_file_name, trim(excel_sheet_name))) then do;
			output;
		end;
		call prxfree(_regex_excel_file_name);
	run;
	quit;
	%local _no_of_excel_sheet;
	%let _no_of_excel_sheet = %&RSUDS.GetCount(&ods_data_loading_control_in_file.) ;
	%if (&_no_of_excel_sheet. = 0) %then %do;
		%&RSULogger.PutInfo(No matched excel sheet in excel file "&i_input_excel_file_path.".)
		%&RSUDS.Delete(&ods_data_loading_control_in_file.)
	%end;
	%else %do;
		%&RSULogger.PutInfo(&_no_of_excel_sheet. excel sheet(s) matched in excel file "&i_input_excel_file_path.".)
	%end;
%mend ConstructLoaderConfigDSInFile;

/**===================================================**/
/* データセット内の変数をスペース区切りで取得（除外分を指定）
/*
/* NOTE: transposeに利用
/**===================================================**/
%macro DataCtrl__GetVariablesExcept(ids_input_ds =
												, i_except =
												, ovar_vars =);
	%local _variable;
	%local _index_variable;
	%local _regex_exclude;
	%do %while(%&RSUUtil.ForEach(i_items = &i_except.
										, ovar_item = _variable
										, iovar_index = _index_variable));
		%&RSUText.Append(iovar_base = _regex_exclude
							, i_append_text = (^&_variable.$)
							, i_delimiter = |);
	%end;
	%&RSUDS.GetDSVariables(&ids_input_ds.
								, i_regex_exclude = /&_regex_exclude./
								, ovar_variables = &ovar_vars.)
%mend DataCtrl__GetVariablesExcept;

/**=========================================**/
/* 縦横変換（横→縦）
/*
/* NOTE: VP 入力データを正規化する際に使用
/* NOTE: 残す変数（i_id_variables）を指定。その他を正規化
/**=========================================**/
%macro DataCtrl__TransposeBy(ids_input_ds =
									, i_by_variables =
									, i_id_variables =
									, ods_transposed_ds =);
	data WORK.tmp_input_ds;
		set &ids_input_ds.;
	run;
	quit;
	%local _var_variables;
	%DataCtrl__GetVariablesExcept(ids_input_ds = WORK.tmp_input_ds
											, i_except = &i_by_variables.
											, ovar_vars = _var_variables)
	%if (not %&RSUUtil.IsMacroBlank(_var_variables)) %then %do;
		proc sort data = WORK.tmp_input_ds out = WORK.tmp_sorted_for_trans;
			by
				&i_by_variables.
			;
		run;
		quit;
		proc transpose data = WORK.tmp_sorted_for_trans out = &ods_transposed_ds.;
			by
				&i_by_variables.
			;
		%if (not %&RSUUtil.IsMacroBlank(i_id_variables)) %then %do;
			id
				&i_id_variables.
			;
		%end;
			var
				&_var_variables.
			;
		run;
		quit;
	%end;
	%else %do;
		data &ods_transposed_ds.;
			set WORK.tmp_input_ds;
			attrib
				COL1 length = $100.
			;
			COL1 = '';
			_NAME_ = 'dummy';
		run;
		quit;
	%end;
	data &ods_transposed_ds.;
		attrib
			_LABEL_ length = $255.
		;
		set &ods_transposed_ds.;
		_LABEL_ = coalescec(_LABEL_, _NAME_);
	run;
	quit;
	%&RSUDS.Delete(WORK.tmp_input_ds WORK.tmp_sorted_for_trans)
%mend DataCtrl__TransposeBy;

/**===================================================**/
/* ディレクトリ内のエクセルファイルをコピー
/**===================================================**/
%macro DataCtrl__CopyExcelFiles(i_src_dir =
										, i_dest_dir =);
	%&RSUDir.GetContents(i_dir_path = &i_src_dir.
								, ods_output_ds = WORK.tmp_all_excel_files_in_dir
								, i_content_type = %&RSUFileType.File
								, i_is_recursive = %&RSUBool.False
								, i_regex = /\.xlsx$/)
	%local _no_of_excel_files;
	%let _no_of_excel_files = %&RSUDS.GetCount(WORK.tmp_all_excel_files_in_dir);
	%local _excel_file_path;
	%local _dsid_excel_file_path;
	%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_all_excel_files_in_dir
										, i_vars = _excel_file_path:_entry_full_path
										, ovar_dsid = _dsid_excel_file_path));
		%&RSUFile.Copy(i_file_path = &_excel_file_path.
							, i_dir_path = &i_dest_dir.)
	%end;
	%&RSULogger.PutInfo(&_no_of_excel_files. excel file(s) has been copied to "&i_dest_dir."...)
	%&RSUDS.Delete(WORK.tmp_all_excel_files_in_dir)
%mend DataCtrl__CopyExcelFiles;

/**===============================================================**/
/* 上書き
/*
/* NOTE: 既存のレコードを上書きする際に順序を変えないようにする
/**===============================================================**/
%macro DataCtrl__Overwrite(iods_base_ds =
									, ids_data_ds =
									, i_by_variables =);
	%if (%&RSUDS.IsDSEmpty(&ids_data_ds.)) %then %do;
		%return;
	%end;
	%local _no_of_overwritten;
	%local _no_of_append;
	%if (0/*%&RSUDS.Exists(&iods_base_ds.)*/) %then %do;
		%&RSULogger.PutNote(Overwriting existing observation by variables: &i_by_variables.)
		%local _by_variable;
		%local _index_by_variable;
		data &iods_base_ds;
			set &iods_base_ds;
			attrib
				_tmp_obs_order_index length = 8.
			;
			_tmp_obs_order_index = _N_;
		run;
		quit;
		data WORK.tmp_updating_data(drop = _rc _no_of_append);
			set &ids_data_ds. end = eof;
			retain _no_of_append 0;
			attrib
				_tmp_obs_order_index length = 8.
			;
			if (_N_ = 1) then do;
				declare hash hh_overwrite(dataset: "&iods_base_ds.");
			%do %while(%&RSUUtil.ForEach(i_items = &i_by_variables.
												, ovar_item = _by_variable
												, iovar_index = _index_by_variable));
				_rc = hh_overwrite.definekey("&_by_variable.");
			%end;
				_rc = hh_overwrite.definedata('_tmp_obs_order_index');
				_rc = hh_overwrite.definedone();
			end;
			_rc = hh_overwrite.find();
			if (_rc ne 0) then do;
				_no_of_append = _no_of_append + 1;
			end;
			if (eof) then do;
				call symputx('_no_of_append', _no_of_append);
			end;
		run;
		quit;

		data &iods_base_ds.(drop = _rc _no_of_deleted);
			set &iods_base_ds. end = eof;
			retain _no_of_deleted 0;
			if (_N_ = 1) then do;
				declare hash hh_overwrite(dataset: "WORK.tmp_updating_data");
			%do %while(%&RSUUtil.ForEach(i_items = &i_by_variables.
												, ovar_item = _by_variable
												, iovar_index = _index_by_variable));
				_rc = hh_overwrite.definekey("&_by_variable.");
			%end;
				_rc = hh_overwrite.definedone();
			end;
			_rc = hh_overwrite.find();
			if (_rc = 0) then do;
				_no_of_deleted = _no_of_deleted + 1;
				delete;
			end;
			if (eof) then do;
				call symputx('_no_of_overwritten', _no_of_deleted);
			end;
		run;
		quit;

		%&RSUDS.Append(iods_base_ds = &iods_base_ds.
							, ids_data_ds = WORK.tmp_updating_data)
		%&RSUDS.Delete(WORK.tmp_updating_data)
		proc sort data = &iods_base_ds. out = &iods_base_ds.(drop = _tmp_obs_order_index);
			by
				_tmp_obs_order_index
			;
		run;
		quit;
	%end;
	%else %do;
		%&RSUDS.Let(i_query = &ids_data_ds.
						, ods_dest_ds = &iods_base_ds.)
		%let _no_of_overwritten = 0;
		%let _no_of_append = %&RSUDS.GetCount(&ids_data_ds.);
	%end;
	%&RSULogger.PutBlock(# of observations overwritten: &_no_of_overwritten.
								, # of observations appended: &_no_of_append.
								, Final # of observations: %&RSUDS.GetCount(&iods_base_ds.))
%mend DataCtrl__Overwrite;