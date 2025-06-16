/*****************************************************/
/* ReportManager.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*****************************************************/
%RSUSetConstant(ReportManager, RptMgr__)

/**==================================**/
/* 既存のエクセルレポート削除
/**==================================**/
%macro RptMgr__ClearExcelReport(i_formula_set_id =);
	%&RSULogger.PutNote(Clearing excel report of "&i_formula_set_id.")
	%local _report_name;
	%local _dsid_rep;
	%local _entry_full_path;
	%local _dsid_excel_file;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_EXCEL_REPORT.(where = (formula_set_id = "&i_formula_set_id."))
										, i_vars = _report_name:report_name
										, ovar_dsid = _dsid_rep));
		%&RSUDir.GetContents(i_dir_path = &G_DIR_USER_DATA_RSLT.
									, ods_output_ds = WORK.tmp_matched_excel_files_in_dir
									, i_content_type = %&RSUFileType.File
									, i_is_recursive = %&RSUBool.False
									, i_regex = /^&_report_name..*\.xlsx$/)
		%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_matched_excel_files_in_dir
											, i_vars = _entry_full_path:_entry_full_path
											, ovar_dsid = _dsid_excel_file));
			%&RSUFile.Delete(&_entry_full_path.)
		%end;
		%&RSUDS.Delete(WORK.tmp_matched_excel_files_in_dir)
	%end;
%mend RptMgr__ClearExcelReport;

/**==================================**/
/* レポート情報保存
/*
/* NOTE: Formula 定義式から
/* NOTE: - formula_set_id
/* NOTE: - formula_definition
/* NOTE: - formula_appl_condition
/* NOTE: - aggregation_coef
/* NOTE: を取り除いた分
/* NOTE: "_aggr"を付与したものも同時に作成
/**==================================**/
%macro RptMgr__SaveReportInfo(iods_formula_definition =);
	%&RSULogger.PutSubsection(Report format of formula)
	%&RSUDebug.PutFootprint(rep0)
	%local /readonly _DS_TMP_FORMULA_ID_LIST = %&RSUDS.GetTempDSName(formula_id_list);
	%&RSUDebug.PutFootprint(rep1)
	%&RSUDS.GetUniqueList(i_query = &iods_formula_definition.(keep = formula_set_id)
								, i_by_variables = formula_set_id
								, ods_output_ds = &_DS_TMP_FORMULA_ID_LIST.)
	%&RSUDebug.PutFootprint(rep2)
	%local /readonly _DS_TMP_SAVING_SOURCE = %&RSUDS.GetTempDSName(saving_source);
	%local /readonly _VAR_ACCOUNT_TITLE_ORDER = account_title_order;
	%&RSUDS.AddSequenceVariable(i_query = &iods_formula_definition.
										, i_sequence_variable_name = &_VAR_ACCOUNT_TITLE_ORDER.
										, ods_dest_ds = &_DS_TMP_SAVING_SOURCE.) 
	%&RSUDebug.PutFootprint(rep3)
	%local _formula_set_id;
	%local _dsid_formula;
	%local _save_report_info;
	%local _ds_tmp_variable_ref_name_list;
	%do %while(%&RSUDS.ForEach(i_query = &_DS_TMP_FORMULA_ID_LIST.
										, i_vars = _formula_set_id:formula_set_id
										, ovar_dsid = _dsid_formula));
		%&RSULogger.PutParagraph(Generating report information of "&_formula_set_id.")
		%let _ds_tmp_variable_ref_name_list = %&RSUDS.GetTempDSName(var_ref_name_list);
		%&RSUDS.GetUniqueList(i_query = &_DS_TMP_SAVING_SOURCE.(where = (formula_set_id = "&_formula_set_id."))
									, i_by_variables = &G_CONST_VAR_VARIABLE_REF_NAME.
									, ods_output_ds = &_ds_tmp_variable_ref_name_list.)
		proc sort 
					data = &_ds_tmp_variable_ref_name_list. 
					out = &_ds_tmp_variable_ref_name_list.(drop = &_VAR_ACCOUNT_TITLE_ORDER.)
				;
			by
				&_VAR_ACCOUNT_TITLE_ORDER.
			;
		run;
		quit;
		%EnrichReportInformation(iods_report_info_ds = &_ds_tmp_variable_ref_name_list.)
		/* 保存 */
		%let _save_report_info = %RptMgr__DSReportInfo(i_formula_set_id = &_formula_set_id.);
		%&Utility.SaveDS(ids_source_ds = &_ds_tmp_variable_ref_name_list.
							, i_save_as = &_save_report_info.
							, i_keep_original = %&RSUBool.True)
		%&Utility.SaveDS(ids_source_ds = &_ds_tmp_variable_ref_name_list.
							, i_save_as = &_save_report_info._aggr)
		%&RSUDS.Delete(&_ds_tmp_variable_ref_name_list.)
	%end;

	data &iods_formula_definition.;
		set &iods_formula_definition.;
		drop
			formula_report_key
			report_format
			scale
			is_hidden	
		;
	run;
	quit;
	%&RSUDebug.PutFootprint(rep4)
	%&RSUDS.Delete(&_DS_TMP_SAVING_SOURCE. &_DS_TMP_FORMULA_ID_LIST.)
%mend RptMgr__SaveReportInfo;

%macro EnrichReportInformation(iods_report_info_ds =);
	data &iods_report_info_ds.;
		set &iods_report_info_ds.;
		attrib
			_node_depth length = 8.
			_formula_order length = 8.
			report_order length = $10.
			formula_key_full length = $100.
			formula_key_leaf length = $100.
			formula_key_formatted length = $100.
			formula_key_full_ordered length = $100.
			formula_key_leaf_ordered length = $100.
			formula_key_formatted_ordered length = $100.
		;
		retain _formula_order 0;
		if (is_hidden ne '1') then do;
			_formula_order = _formula_order + 1;
			_node_depth = count(formula_report_key, '|');
			report_order = cats('(', put(_formula_order, &G_SETTING_FORMULA_ORDER_FORMAT.), ')');
			formula_key_full = formula_report_key;
			formula_key_leaf = scan(formula_key_full, -1, '|');
			formula_key_formatted = formula_key_leaf;
			do _i = 1 to _node_depth;
				formula_key_formatted = cat(&G_CONST_ACCOUNT_TITLE_INDENT., trim(formula_key_formatted));
			end;
			formula_key_full_ordered = cats(formula_order, formula_key_full);
			formula_key_leaf_ordered = cats(formula_order, formula_key_leaf);
			formula_key_formatted_ordered = cat(trim(formula_order), formula_key_formatted);
			output;
		end;
		keep
			formula_report_key
			report_format
			scale
			report_order
			formula_key_full
			formula_key_leaf
			formula_key_formatted
			formula_key_full_ordered
			formula_key_leaf_ordered
			formula_key_formatted_ordered
		;
	run;
	quit;
%mend EnrichReportInformation;

/**================================================*/
/* 計算結果のフォーマッティング
/*
/* NOTE: 表示/非表示
/* NOTE: スケーリング
/* NOTE: 表示フォーマット
/* ! &G_CONST_VAR_VARIABLE_REF_NAME. に依存する箇所があるので、計算実行後に呼び出される
/**================================================*/
%macro RptMgr__SaveFormattedResult(ids_raw_result =
											, ids_report_info_ds =
											, i_save_data_as =);
	%&RSULogger.PutNote(Formatting result dataset "&ids_raw_result." and saving it)
	%&RSULogger.PutBlock(Fomatting profile:
								, Raw Dataset: &ids_raw_result.
								, Report format: &ids_report_info_ds.)
	%&RSUDS.Delete(&i_save_data_as.)

	data &i_save_data_as.(drop = _rc);
		if (_N_ = 0) then do;
			set &ids_report_info_ds.;
		end;
		set &ids_raw_result.;
		if (_N_ = 1) then do;
			declare hash hh_report(dataset: "&ids_report_info_ds.");
			_rc = hh_report.definekey("&G_CONST_VAR_VARIABLE_REF_NAME.");
			_rc = hh_report.definedata(all: 'y');
			_rc = hh_report.definedone();
		end;
		&G_CONST_VAR_VARIABLE_REF_NAME. = scan(scan(value_key, -1, '!'), 1, '}');
		_rc = hh_report.find();
		if (_rc = 0) then do;
			output;
		end;
	run;
	quit;
	%AddTextTimeVariable(iods_result_ds = &i_save_data_as.)
	%FormatResultValue(iods_result_ds = &i_save_data_as.)
	%if (%&RSUDS.IsDSEmpty(&i_save_data_as.)) %then %do;
		%&RSULogger.PutInfo(Result dataset not seved (All values are hidden).)
		%&RSUDS.Delete(&i_save_data_as.)
	%end;
	%else %do;
		%&RSULogger.PutInfo(Formatted result has been saved as "&i_save_data_as".)
	%end;
%mend RptMgr__SaveFormattedResult;

/*------------------------*/
/*	時間変数処理
/*	! 分類変数に使うので、文字列でないといけない。
/*	! 数字だけだとうまくいかないので、 "_" を付与している
/*------------------------*/
%macro AddTextTimeVariable(iods_result_ds =);
	data &iods_result_ds.;
		set &iods_result_ds.;
		attrib
			time length = $10.
		;
		time = cats('_', put(&G_CONST_VAR_TIME., BEST.));
	run;
	quit;
%mend AddTextTimeVariable;

/*--------------------------------------*/
/* 数字スケール・フォーマット変換 非表示
/*--------------------------------------*/
%macro FormatResultValue(iods_result_ds =);
	data &iods_result_ds.;
		set &iods_result_ds.;
		attrib
			value_org length = $100.
			value_formatted length = $100.
		;
		value_org = &G_CONST_VAR_VALUE.;
		value_number = input(&G_CONST_VAR_VALUE., BEST.);
		if (not missing(value_number)) then do;
			value_scaled = value_number / scale;
		end;
		if (not missing(value_scaled)) then do;
			value_formatted = compress(putn(value_scaled, report_format));
		end;
		else do;
			value_formatted = &G_CONST_VAR_VALUE.;
		end;
		drop
			report_format
			scale
		;
	run;
	quit;
%mend FormatResultValue;

/**================================================*/
/* レポート（エクセル）作成
/*
/* NOTE: 1つのFormula 結果に対して1つのエクセルを作成
/* NOTE: 1つのエクセルシート内には1つのテーブルのみを含む
/*
/* NOTE: Formula のレイヤー + 変数名を
/* NOTE: ファイル名
/* NOTE: シート名
/* NOTE: キー変数
/* NOTE: カラム
/* NOTE: に分配 
/*
/* ! 複数段のヘッダーには対応せず
/**================================================*/
%macro RptMgr__GenerateExcelReport(i_formula_set_id =);
	%local _no_of_excel_reporting_tasks;
	%let _no_of_excel_reporting_tasks = %&RSUDS.GetCount(&G_SETTING_CONFIG_DS_EXCEL_REPORT.(where = (formula_set_id = "&i_formula_set_id.")));
	%&RSULogger.PutSubsection(Excel report(s) will be generated from result of "&i_formula_set_id.")
	%local _report_name;
	%local _source_ds;
	%local _filter;
	%local _variable_file_name;
	%local _sheet_name_template;
	%local _variable_sheet_name;
	%local _variable_ds_name;
	%local _variables_row;
	%local _variables_col;
	%local _dsid_rep;
	%local _file_name;
	%local _sheet_name;
	%local _filter_code;
	%local _drop_code;
	%local _ds_title;
	%local _dsid_file_name;
	%local _dsid_sheet_name;
	%local _dsid_ds_name;
	%local _val_colum;
	%local _index_val_column;
	%local _vairable_ref_name_col_def;
	%local _val_col_style;
	%local _excel_reports;
	%local _variable_row;
	%local _index_variable_row;
	%local _variable_row_list;
	%local _variable_row_label_code;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_EXCEL_REPORT.(where = (formula_set_id = "&i_formula_set_id."))
										, i_vars = _report_name:report_name
													_source_ds:source_ds
													_filter:filter
													_variable_file_name:variable_file_name
													_sheet_name_template:sheet_name_template
													_variable_sheet_name:variable_sheet_name
													_variable_ds_name:variable_ds_name
													_variables_row:variables_row
													_variables_col:variables_col
										, ovar_dsid = _dsid_rep));
		%if (not %&RSUDS.Exists(&G_CONST_LIB_RSLT..&_source_ds.)) %then %do;
			%&RSULogger.PutWarning(Result dataset &G_CONST_LIB_RSLT..&_source_ds. not found. Check configuration.)
			%goto __skip_generaye_excel_rep;
		%end;
		%&RSULogger.PutParagraph(Generating excel report "&_report_name.")
		%&RSULogger.PutBlock(Input data: &G_CONST_LIB_RSLT..&_source_ds.
									, Variable for excel file name: &_variable_file_name.
									, Variable for excel sheet name: &_variable_sheet_name.
									, Variable for dataset: &_variable_ds_name.
									, Variable for row: &_variables_row.
									, Variable for column: &_variables_col.)
		%let _variable_row_list =;
		%do %while(%&RSUUtil.ForEach(i_items = &_variables_row., ovar_item = _variable_row, iovar_index = _index_variable_row));
			%&RSUText.Append(iovar_base = _variable_row_list
								, i_append_text = %scan(&_variable_row., 1, :))
		%end;
		%PrepareReportSourceDS(i_source_ds = &G_CONST_LIB_RSLT..&_source_ds.
									, i_filter = %quote(&_filter.)
									, i_by_variables = &_variable_file_name. &_variable_sheet_name. &_variable_ds_name. &_variable_row_list.
									, i_id_variable = &_variables_col.
									, ods_output_report_source = WORK.tmp_excel_report_ds)
		%GenerateExcelFileList(ids_source_ds = WORK.tmp_excel_report_ds
									, i_file_name_template = &_report_name.
									, i_distributon_var_name = &_variable_file_name.
									, ods_output_file_name_list = WORK.tmp_excel_rep_file_name_list)
		%GenerateExcelSheetList(ids_source_ds = WORK.tmp_excel_report_ds
										, i_sheet_name_template = &_sheet_name_template.
										, i_distributon_var_name = &_variable_sheet_name.
										, ods_output_sheet_name_list = WORK.tmp_excel_rep_sheet_name_list)
		%GenerateReportDatasetList(ids_source_ds = WORK.tmp_excel_report_ds
											, i_dataset_name_template = dummy
											, i_distributon_var_name = &_variable_ds_name.
											, ods_output_dataset_list = WORK.tmp_excel_rep_dataset_list)
		%let _excel_reports =;
		%local _value_column_names;
		%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_excel_rep_file_name_list
											, i_vars = _file_name:object_name 
														_filter_code:filter_code 
														_drop_code:drop_code
											, ovar_dsid = _dsid_file_name));
			data WORK.tmp_excel_report_file_filtered;
				set WORK.tmp_excel_report_ds;
				&_filter_code.
				&_drop_code.
			run;
			quit;
			%GenerateExcelReportOpen(i_excel_file_path = &G_DIR_USER_DATA_RSLT./&_file_name.)
			%&RSUText.Append(iovar_base = _excel_reports
								, i_append_text = &_file_name.)
			%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_excel_rep_sheet_name_list
												, i_vars = _sheet_name:object_name
															_filter_code:filter_code 
															_drop_code:drop_code
												, ovar_dsid = _dsid_sheet_name));
				data WORK.tmp_excel_report_sheet_filtered;
					set WORK.tmp_excel_report_file_filtered;
					&_filter_code.
					&_drop_code.
				run;
				quit;
				%GenerateExcelReportSheet(i_sheet_name = &_sheet_name.)
				%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_excel_rep_dataset_list
													, i_vars = _filter_code:filter_code
																_drop_code:drop_code
																_ds_title:ds_title
													, ovar_dsid = _dsid_ds_name));
					data WORK.tmp_excel_report_ds;
						set WORK.tmp_excel_report_sheet_filtered;
						&_filter_code.
						&_drop_code.
					run;
					quit;

					%if (not %&RSUUtil.IsMacroBlank(_ds_title)) %then %do;
						proc odstext;
							p "&_ds_title.";
						run;
						quit;
					%end;
					%if (%&RSUDS.IsVarDefined(ids_dataset = WORK.tmp_excel_report_ds, i_var_name = formula_key_formatted)) %then %do;
						%let _vairable_ref_name_col_def = define formula_key_formatted / style(column) = [asis=on] display;
					%end;
					%&DataController.GetVariablesExcept(ids_input_ds = WORK.tmp_excel_report_ds
																	, i_except = &_variable_row_list.
																	, ovar_vars = _value_column_names)
					%do %while(%&RSUUtil.ForEach(i_items = &_value_column_names., ovar_item = _val_colum, iovar_index = _index_val_column));
						%&RSUText.Append(iovar_base = _val_col_style
											, i_append_text = define "&_val_colum."n / style(column) = [asis=on just=right] display;)
					%end;
					%let _index_var_row =;
					data WORK.tmp_excel_report_ds;
						set WORK.tmp_excel_report_ds;
					%do %while(%&RSUUtil.ForEach(i_items = &_variables_row., ovar_item = _variable_row, iovar_index = _index_var_row));
						label %scan(&_variable_row., 1, :) = "%scan(&_variable_row., 2, :)";
					%end;
					run;
					quit;
					proc report data = WORK.tmp_excel_report_ds;
						&_vairable_ref_name_col_def.;
						&_val_col_style.;
					run;
					quit;
					ods excel options(sheet_interval = 'NONE');
					%&RSUDS.Delete(WORK.tmp_excel_report_ds)
				%end;
				ods excel options(sheet_interval = 'NOW');
			%end;
			%CloseExcelReport()
		%end;
		%&Stratum.AttachExcelReport(i_excel_reports = &_excel_reports.)
%__skip_generaye_excel_rep:
	%end;
	%&RSUDS.Delete(WORK.tmp_excel_report_file_filtered WORK.tmp_excel_report_sheet_filtered WORK.tmp_excel_report_ds WORK.tmp_excel_rep_dataset_list WORK.tmp_excel_rep_sheet_name_list WORK.tmp_excel_rep_file_name_list)
%mend RptMgr__GenerateExcelReport;

/*-------------------------------------------*/
/* レポーティング用データ準備.
/*
/* NOTE: フィルター
/*
/* NOTE: 順序を保った状態での縦横変換
/* NOTE: Step1. id に変換（変数名をそのままに、内容を名称からidに切り替える）
/* NOTE: Transpose用にsort
/* NOTE: ID変数を名称に戻す
/* NOTE: Transpose
/* NOTE: by 変数をid→名称変換（変数名をそのままに、内容をidから名称に切り替える）
/*
/* NOTE: 時間軸: そのまま（変換しない）
/* NOTE: それ以外: マスタを利用
/*-------------------------------------------*/
%macro PrepareReportSourceDS(i_source_ds =
									, i_filter =
									, i_by_variables =
									, i_id_variable =
									, ods_output_report_source =);
	/* フィルター */
	data WORK.tmp_report_source;
		set &i_source_ds.;
	%if (not %&RSUUtil.IsMacroBlank(i_filter)) %then %do;
		where
			&i_filter.
		;
	%end;
	run;
	quit;

	proc sort data = WORK.tmp_report_source;
		by
			&i_by_variables.
			&i_id_variable.
		;
	run;
	quit;

	proc transpose data = WORK.tmp_report_source out = &ods_output_report_source.(drop = _NAME_);
		by
			&i_by_variables.
		;
		var
			value_formatted
		;
		id
			&i_id_variable.
		;
	run;
	quit;
	%&RSUDS.Delete(WORK.tmp_report_source)
%mend PrepareReportSourceDS;

/*-------------------------------*/
/* 出力データセットリスト作成
/*-------------------------------*/
%macro GenerateReportDatasetList(ids_source_ds =
											, i_dataset_name_template =
											, i_distributon_var_name =
											, ods_output_dataset_list =);
	%GenerateDistHelper(ids_source_ds = &ids_source_ds.
								, i_distributon_var_name = &i_distributon_var_name.
								, ods_output_dataset_list = &ods_output_dataset_list.)

	%if (%&RSUUtil.IsMacroBlank(i_distributon_var_name)) %then %do;
		data &ods_output_dataset_list.;
			set &ods_output_dataset_list.;
			attrib
				object_name length = $32.
				ds_title length = $500.
			;
			object_name = "&G_CONST_LIB_RSLT..&i_dataset_name_template.";
			ds_title = '';
		run;
		quit;
	%end;
	%else %do;
		%local _dist_var;
		%local _index_dist_var;
		data &ods_output_dataset_list.;
			set &ods_output_dataset_list.;
			attrib
				object_name length = $32.
				ds_title length = $500.
			;
			object_name = "&G_CONST_LIB_RSLT..&i_dataset_name_template.";
		%do %while(%&RSUUtil.ForEach(i_items =&i_distributon_var_name., ovar_item = _dist_var, iovar_index = _index_dist_var));
			object_name = catx('_', object_name, &_dist_var.);
			ds_title = catx(' ', ds_title, catx('=', "&_dist_var.", cats("'", &_dist_var., "'")));
		%end;
			drop
				&i_distributon_var_name.
			;
		run;
		quit;
	%end;
%mend GenerateReportDatasetList;

%macro GenerateExcelFileList(ids_source_ds =
									, i_file_name_template =
									, i_distributon_var_name =
									, ods_output_file_name_list =);
	%GenerateDistHelper(ids_source_ds = &ids_source_ds.
							, i_distributon_var_name = &i_distributon_var_name.
							, ods_output_dataset_list = &ods_output_file_name_list.)

	%if (%&RSUUtil.IsMacroBlank(i_distributon_var_name)) %then %do;
		data &ods_output_file_name_list.;
			set &ods_output_file_name_list.;
			attrib
				object_name length = $32.
			;
			object_name = "&i_file_name_template..xlsx";
		run;
		quit;
	%end;
	%else %do;
		%local _dist_var;
		%local _index_dist_var;
		data &ods_output_file_name_list.;
			set &ods_output_file_name_list.;
			attrib
				object_name length = $32.
			;
			object_name = "&i_file_name_template.";
		%do %while(%&RSUUtil.ForEach(i_items =&i_distributon_var_name., ovar_item = _dist_var, iovar_index = _index_dist_var));
			object_name = catx(object_name, cats('{', &_dist_var., '}'));
		%end;
			object_name = cats(object_name, '.xlsx');
			drop
				&i_distributon_var_name.
			;
		run;
		quit;
	%end;
%mend GenerateExcelFileList;

%macro GenerateExcelSheetList(ids_source_ds =
										, i_sheet_name_template =
										, i_distributon_var_name =
										, ods_output_sheet_name_list =);
	%GenerateDistHelper(ids_source_ds = &ids_source_ds.
								, i_distributon_var_name = &i_distributon_var_name.
								, ods_output_dataset_list = &ods_output_sheet_name_list.)
	%if (%&RSUUtil.IsMacroBlank(i_distributon_var_name)) %then %do;
		data &ods_output_sheet_name_list.;
			set &ods_output_sheet_name_list.;
			attrib
				object_name length = $32.
			;
			object_name = "&i_sheet_name_template.";
		run;
		quit;
	%end;
	%else %do;
		%local _dist_var;
		%local _index_dist_var;
		data &ods_output_sheet_name_list.;
			set &ods_output_sheet_name_list.;
			attrib
				object_name length = $32.
			;
			object_name = "&i_sheet_name_template.";
		%do %while(%&RSUUtil.ForEach(i_items =&i_distributon_var_name., ovar_item = _dist_var, iovar_index = _index_dist_var));
			object_name = cats(object_name, cats('{', &_dist_var., '}'));
		%end;
			drop
				&i_distributon_var_name.
			;
		run;
		quit;
	%end;
%mend GenerateExcelSheetList;

%macro GenerateDistHelper(ids_source_ds =
								, i_distributon_var_name =
								, ods_output_dataset_list =);
	%if (%&RSUUtil.IsMacroBlank(i_distributon_var_name)) %then %do;
		data &ods_output_dataset_list.;
			attrib
				filter_code length = $500.
				drop_code length = $500.
			;
			filter_code = '';
			drop_code = '';
		run;
		quit;
	%end;
	%else %do;
		%&RSUDS.GetUniqueList(i_query = &ids_source_ds.(keep = &i_distributon_var_name.)
									, i_by_variables = &i_distributon_var_name.
									, ods_output_ds = WORK.tmp_dist_var_list)
		%local _dist_var;
		%local _index_dist_var;
		data &ods_output_dataset_list.;
			set WORK.tmp_dist_var_list;
			attrib
				filter_code length = $500.
				drop_code length = $500.
			;
			filter_code = 'where 1 ';
			drop_code = 'drop';
		%do %while(%&RSUUtil.ForEach(i_items =&i_distributon_var_name., ovar_item = _dist_var, iovar_index = _index_dist_var));
			filter_code = catx(' and ', filter_code, catx('=', "&_dist_var.", cats("'", &_dist_var., "'")));
			drop_code = catx(' ', drop_code, "&_dist_var.");
		%end;
			filter_code = cats(filter_code, ';');
			drop_code = cats(drop_code, ';');
		run;
		quit;
		%&RSUDS.Delete(WORK.tmp_dist_var_list)
	%end;
%mend GenerateDistHelper;

%macro GenerateExcelReportOpen(i_excel_file_path =);
	ods excel file = "&i_excel_file_path.";
	ods excel options(sheet_interval = 'NONE');
%mend GenerateExcelReportOpen;

%macro GenerateExcelReportSheet(i_sheet_name =);
	ods excel options(sheet_name = "&i_sheet_name." embedded_titles = 'yes');
%mend GenerateExcelReportSheet;

%macro CloseExcelReport();
	ods excel close;
%mend CloseExcelReport;

%macro RptMgr__DSReportInfo(i_formula_set_id =);
	&G_CONST_LIB_WORK..rep_info_&i_formula_set_id.
%mend RptMgr__DSReportInfo;
