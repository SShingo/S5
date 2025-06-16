/************************************************************************************************/
/* ExternalValueLoader.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: Formula 式が参照するデータ（数値、属性）読み込み
/* NOTE: Excelからデータを読み込み、正規化、データセット保持
/* !入力データはすべてExcel前提
/*
/* NOTE: Excelからの入力データは2種類の形式に制限
/* NOTE: [Horizontal Format]: 各種属性を列で定義した行の集合
/* NOTE: 例: 債務者属性
/* NOTE: 債務者コード | 債務者名 | 業種ID | 属性A | 属性B | ....
/*
/* NOTE: [Vertical Format]: 変数のBreak Downを行で保持する形式
/* NOTE: 例: 法定耐用年数
/* NOTE: 電源種別 | 法定耐用年数
/*
/* NOTE: これらのデータが読み込まれた後、Value Pool ID別（Value Pool 毎にデータ粒度が異なる → テーブルフォーマットが違う）にデータセットが生成される
/* NOTE: Value Poolのフォーマット：
/* NOTE: layerX | layerY | ... | var | value
/*
/* NOTE: Value Pool の本体であるデータセットは L_WORK.vp_<value_pool_id>.sas7bdat として保存される
/*
/* NOTE: "Scenario.xlsx"は自動探索
/************************************************************************************************/
%RSUSetConstant(ExternalValueLoader, ExtValLdr__)
%RSUSetConstant(G_CONST_VAR_LEN_DATA, 2)

/**======================================================**/
/* 外部データ読み込み
/*
/* NOTE: データ読み込み制御ファイル作成
/* NOTE: データ読み込み
/**======================================================**/
%macro ExtValLdr__LoadFile();
	%if (%&RSUDS.IsDSEmpty(&G_SETTING_CONFIG_DS_LOADING_DATA.)) %then %do;
		%&RSULogger.PutInfo(No value pool is loaded)
		%return;
	%end;
	
	%&RSULogger.PutSubsection(Value pool loading...)
	%local _directory;
	%local _index_directory;
	%&RSUDS.Delete(WORK.tmp_value_pool_definition)
	%local _index;
	%do %while(%&RSUUtil.ForEach(i_items = &G_DIR_USER_DATA_RSLT_DIR2_PREDEF. &G_DIR_USER_DATA_RSLT_DIR1_STG.
										, ovar_item = _directory
										, iovar_index = _index_directory));
		%&RSULogger.PutNote(Searching loading data in "&_directory." and Loading data.)
		%ConstructLoaderConfigDSInDir(ids_data_loading_config = &G_SETTING_CONFIG_DS_LOADING_DATA.
												, i_input_dir = &_directory.
												, ods_data_loading_control_in_dir = WORK.tmp_data_loading_control_in_dir)
		%if (%&RSUDS.Exists(WORK.tmp_data_loading_control_in_dir)) %then %do;
			%LoadDataIntoValuePool(ids_data_loading_control = WORK.tmp_data_loading_control_in_dir)
			%&RSUDS.Delete(WORK.tmp_data_loading_control_in_dir)
		%end;
	%end;
%mend ExtValLdr__LoadFile;

/*---------------------------------------------------------*/
/* データロード.
/*---------------------------------------------------------*/
%macro LoadDataIntoValuePool(ids_data_loading_control =);
	%local /readonly _NO_OF_PARAMETER_TABLES = %&RSUDS.GetCount(&ids_data_loading_control.);
	%if (&_NO_OF_PARAMETER_TABLES. = 0) %then %do;
		%return;
	%end;

	%&RSULogger.PutNote(Loading excel data and creating Value Pool(s)...)
	/* データロード */
/*	%&RSUDS.GetUniqueList(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.
								, i_by_variables = data_id
								, ods_output_ds = WORK.tmp_unique_data_id)*/
	%local _data_id;
	%local _full_classification_variables;
	%local _dsid_data_id;
	%local _index_data_id;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_LOADING_DATA.
										, i_vars = _data_id:data_id
/*													_full_classification_variables:full_classification_variables*/
										, ovar_dsid = _dsid_data_id));
		%LoadEachDataIntoValuePool(i_data_id = &_data_id.
											, iovar_index_data_id = _index_data_id
											, ids_data_loading_control = &ids_data_loading_control.
											, ods_loaded_data = WORK.tmp_loaded_value_pool)
		%if (%&RSUDS.Exists(WORK.tmp_loaded_value_pool)) %then %do;
			%&DataController.Overwrite(iods_base_ds = %&DataObject.DSVariablePart(i_suffix = &_data_id.)
												, ids_data_ds = WORK.tmp_loaded_value_pool
												, i_by_variables = /*&_full_classification_variables.*/ &G_CONST_VAR_VARIABLE_REF_NAME. )
			%&RSUDS.Delete(WORK.tmp_loaded_value_pool)
		%end;
	%end;
	%&RSUDS.Delete(WORK.tmp_unique_data_id WORK.tmp_layer_info)
%mend LoadDataIntoValuePool;

/*---------------------------------------------------------*/
/* 各data_id データロード.
/*
/* NOTE: データロード制御データセット に従ってValue Poolを作成
/* NOTE: 同一キーのものはStagingデータ優先
/*---------------------------------------------------------*/
%macro LoadEachDataIntoValuePool(i_data_id =
											, iovar_index_data_id =
											, ids_data_loading_control =
											, ods_loaded_data =);
	%&RSUDS.Delete(WORK.tmp_total_value_pool)
	%local /readonly _NO_OF_DATA_ID = %&RSUDS.GetCount(&ids_data_loading_control.);
	%local /readonly _NO_OF_DATA_SOURCE = %&RSUDS.GetCount(&ids_data_loading_control.(where = (data_id = "&i_data_id.")));
	%if (&_NO_OF_DATA_SOURCE. = 0) %then %do;
		%return;
	%end;
	%local /readonly _HORIZON_AS_OF = %&CalculationSetting.Get(i_key = horizon_as_of);

	%local _excel_file_path;
	%local _excel_file_name;
	%local _excel_file_name_regex;
	%local _excel_sheet_name;
	%local _excel_sheet_name_regex;
	%local _schema_name;
	%local _additional_value_vars;
	%local _value_class_vars;
	%local _dsid_loading_cntrol;
	%&RSULogger.PutParagraph(%&RSUCounter.Draw(i_max_index = &_NO_OF_DATA_ID., iovar_index = &iovar_index_data_id.) Input data "&i_data_id." is being loaded (&_NO_OF_DATA_SOURCE. data source(s))..)
	%local _index_sheet;
	%&RSUDS.Delete(&ods_loaded_data.)
	%do %while(%&RSUDS.ForEach(i_query = &ids_data_loading_control.(where = (data_id = "&i_data_id."))
										, i_vars = _excel_file_path:excel_file_path 
														_excel_file_name:excel_file_name 
														_excel_file_name_regex:excel_file_name_regex 
														_excel_sheet_name:excel_sheet_name
														_excel_sheet_name_regex:excel_sheet_name_regex
														_schema_name:schema_name
														_additional_value_vars:additional_value_vars
														_value_class_vars:value_class_vars 
										, ovar_dsid = _dsid_loading_cntrol));
		%&RSULogger.PutInfo(Loading process #&&&iovar_index_data_id. / &_NO_OF_DATA_ID. - %&RSUCounter.Draw(i_max_index = &_NO_OF_DATA_SOURCE., iovar_index = _index_sheet)...)
		%&DataController.LoadExcel(i_excel_file_path = &_excel_file_path.
											, i_setting_excel_file_path = &G_FILE_APPLICATION_CONFIG.
											, i_schema_name = &_schema_name.
											, i_sheet_name = &_excel_sheet_name.
											, ods_output_ds = WORK.tmp_unit_loaded_data)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUDS.TerminateLoop(_dsid_loading_cntrol)
			%goto _leave_load_each_data;
		%end;
		%&RSULogger.PutNote(Defining value pool: "&i_data_id.")
		/* 変数追加1（エクセルファイル名） */
		%AddNewVariableFromExcelInfo(iods_source_ds = WORK.tmp_unit_loaded_data
											, i_variable_def_source = &_excel_file_name.
											, i_variable_def_regex = &_excel_file_name_regex.
											, i_additional_variable_body = file_name)
		/* 変数追加2（エクセルシート名） */
		%AddNewVariableFromExcelInfo(iods_source_ds = WORK.tmp_unit_loaded_data
											, i_variable_def_source = &_excel_sheet_name.
											, i_variable_def_regex = &_excel_sheet_name_regex.
											, i_additional_variable_body = sheet_name)
		/* 変数追加3（分類変数）*/
		%if (not %&RSUUtil.IsMacroBlank(_additional_value_vars)) %then %do;
			%AddNewValueVariables(iods_source_ds = WORK.tmp_unit_loaded_data
										, i_additional_value_vars = &_additional_value_vars.)
		%end;

		/* 正規化 */
		%NormalizeInputData(ids_input_ds = WORK.tmp_unit_loaded_data
								, i_value_classifiction_var = &_value_class_vars.
								, ods_output_ds = WORK.tmp_unit_loaded_data_normalized)
		%&RSUDS.Delete(WORK.tmp_unit_loaded_data)
		/* 連結 */
		%&RSUDS.Append(iods_base_ds = &ods_loaded_data.
							, ids_data_ds = WORK.tmp_unit_loaded_data_normalized)
		%&RSUDS.Delete(WORK.tmp_unit_loaded_data_normalized)
	%end;
	%return;
%_leave_load_each_data:
%mend LoadEachDataIntoValuePool;

/*-----------------------------------------------------------------------------------*/
/*	新規変数追加
/*
/* NOTE: Excelファイル名、Excelシート名から抽出された情報を変数として追加
/*-----------------------------------------------------------------------------------*/
%macro AddNewVariableFromExcelInfo(iods_source_ds =
											, i_variable_def_source =
											, i_variable_def_regex =
											, i_additional_variable_body =);
	%&RSULogger.PutNote(Extracting additional attribute variable name from Excel file/sheet name. "&i_variable_def_source."..)
	%local /readonly _REGEX_CAPTURE_ITER = %&RSURegex.CreateCaptureIterator(i_regex_expression = /&i_variable_def_regex./
																									, i_text = &i_variable_def_source.);
	%local _text;
	%local _index;
	%do %while(%&_REGEX_CAPTURE_ITER.Next());
		%do %while(%&_REGEX_CAPTURE_ITER.NextPos());
			%let _text = %&_REGEX_CAPTURE_ITER.CurrentPosText();
			%let _index = %&_REGEX_CAPTURE_ITER.CurrentPosIndex();
			%&RSULogger.PutInfo(New attribute variable "_&i_additional_variable_body._&_index._ = &_text." added)
			data &iods_source_ds.;
				set &iods_source_ds.;
				attrib
					_&i_additional_variable_body._&_index._ length = $200. label = "&_text."
				;
				_&i_additional_variable_body._&_index._ = "&_text.";
			run;
			quit;
		%end;
	%end;

	%&RSUClass.Dispose(_REGEX_CAPTURE_ITER)
%mend AddNewVariableFromExcelInfo;

/*-------------------------------------------------*/
/* 新規属性変数生成
/*
/* NOTE: 分類変数を属性として使えるようにコピー
/*-------------------------------------------------*/
%macro AddNewValueVariables(iods_source_ds =
									, i_additional_value_vars =);
	%&RSULogger.PutNote(Adding new value variables "&i_additional_value_vars."...)
	%&RSUDS.CloneVariable(iods_dataset = &iods_source_ds.
								, i_target_variables = &i_additional_value_vars.)
%mend AddNewValueVariables;

/*--------------------------------------------------------------------*/
/* 入力データ正規化
/*--------------------------------------------------------------------*/
%macro NormalizeInputData(ids_input_ds =
								, i_value_classifiction_var =
								, ods_output_ds =);
	%&RSULogger.PutNote(Transposing input dataset by (&i_value_classifiction_var.)...)
	%&DataController.TransposeBy(ids_input_ds = &ids_input_ds.
											, i_by_variables = &i_value_classifiction_var.
											, ods_transposed_ds = &ods_output_ds.)
%mend NormalizeInputData;
