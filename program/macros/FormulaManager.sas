/***********************************************************/
/* FormulaManager.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***********************************************************/
%RSUSetConstant(FormulaManager, FormMgr__)

/**================================================================================================**/
/* Formula 作成.
/*
/* NOTE: Formula はシートに分けては1ファイルに定義されているものとする
/* NOTE: ロードデータを1テーブルに保持
/**================================================================================================**/
%macro FormMgr__CreateDSFromExcel(ods_raw_formula =);
	%&RSULogger.PutSubsection(Formula definition)

	%&RSUDebug.PutFootprint(i_msg = test0)
	%local /readonly _TMP_DS_FORMULA_EXCEL_LDR_CTL = %&RSUDS.GetTempDSName(load_ctr);
	%local /readonly _TMP_DS_FORMULA_EXCEL = %&RSUDS.GetTempDSName(form_def);
	%SetExcelFileName(ods_config_formula_def = &_TMP_DS_FORMULA_EXCEL.)
	%local _directory;
	%local _index_directory;
	%local _directory_leaf;
	%&RSUDS.Delete(&ods_raw_formula.)
	%do %while(%&RSUUtil.ForEach(i_items = &G_DIR_USER_DATA_RSLT_DIR2_PREDEF. &G_DIR_USER_DATA_RSLT_DIR1_STG.
										, ovar_item = _directory
										, iovar_index = _index_directory));
		%let _directory_leaf = %sysfunc(scan(&_directory., -1, /));
		%&RSULogger.PutNote(Searching loading data in "&_directory." and Loading data.)
		%ConstructLoaderConfigDSInDir(ids_data_loading_config = &_TMP_DS_FORMULA_EXCEL.
												, i_input_dir = &_directory.
												, ods_data_loading_control_in_dir = &_TMP_DS_FORMULA_EXCEL_LDR_CTL.)
		%if (%&RSUDS.Exists(&_TMP_DS_FORMULA_EXCEL_LDR_CTL.)) %then %do;
			%LoadFormulaDefintion(ids_data_loading_control = &_TMP_DS_FORMULA_EXCEL_LDR_CTL.
										, i_directory_leaf = &_directory_leaf.
										, iods_output_ds = &ods_raw_formula.)
			%if (%&RSUError.Catch()) %then %do;
				%&RSUError.Throw(Failed to load formula definition)
				%return;
			%end;
			%&RSUDS.Delete(&_TMP_DS_FORMULA_EXCEL_LDR_CTL.)
		%end;
	%end;
	%&RSUDS.Delete(&_TMP_DS_FORMULA_EXCEL.)

	%if (%&RSUDS.IsDSEmpty(&ods_raw_formula.)) %then %do;
		%&RSUError.Throw(No formula definition found.
							, i_is_continue = %&RSUBool.True)
		%return;
	%end;
%mend FormMgr__CreateDSFromExcel;

/*-----------------------------------------------------*/
/* ファイル名設定
/*-----------------------------------------------------*/
%macro SetExcelFileName(ods_config_formula_def =);
	%&RSUDebug.PutFootprint(i_msg = test1)
	%local /readonly _FORMULA_VRESION = %&CalculationSetting.Get(i_key = formula_version);
	%&RSUDebug.PutFootprint(i_msg = test1.5)
	data &ods_config_formula_def.;
		attrib
			excel_file_name_regex length = $100.
		;
		set &G_SETTING_CONFIG_DS_FORMULA_DEF.;
		excel_file_name_regex = cats('^', "&G_SETTING_FORMULA_DEF_FILE_NAME.", '\{', "&_FORMULA_VRESION.", '\}\.xlsx$');
	run;
	quit;
%mend SetExcelFileName;

/*-------------------------------------------------------------------------------------------------*/
/* Formula ロード
/*
/* NOTE: formula_type = {Genera Formula, Rating Formula}
/*-------------------------------------------------------------------------------------------------*/
%macro LoadFormulaDefintion(ids_data_loading_control =
									, i_directory_leaf =
									, iods_output_ds =);
	%local /readonly _NO_OF_FORMULA_SET = %&RSUDS.GetCount(&ids_data_loading_control.);
	%local /readonly _TMP_DS_FULL_FORMULA_IN_DIR = %&RSUDS.GetTempDSName(full_formula_in_dir);
	%local /readonly _TMP_DS_UNIT_FORMULA_IN_DIR = %&RSUDS.GetTempDSName(unit_formula_in_dir);
	/* 読み込み */
	%local _formula_set_id;
	%local _excel_file_path;
	%local _excel_sheet_name;
	%local _dsid_loading_cntrol;
	%local _dsid_formula_set;
	%local _index_formula_set;
	%&RSUDS.Delete(&_TMP_DS_FULL_FORMULA_IN_DIR.)
	%do %while(%&RSUDS.ForEach(i_query = &ids_data_loading_control.
										, i_vars = _formula_set_id:formula_set_id
													_excel_file_path:excel_file_path 
													_excel_sheet_name:excel_sheet_name 
										, ovar_dsid = _dsid_formula_set));
		%&RSULogger.PutParagraph([&i_directory_leaf.] %&RSUCounter.Draw(i_max_index = &_NO_OF_FORMULA_SET., iovar_index = _index_formula_set) Formula "&_formula_set_id." is being loaded...)
		%&DataController.LoadExcel(i_excel_file_path = &_excel_file_path.
											, i_setting_excel_file_path = &G_FILE_SYSTEM_SETTING.
											, i_schema_name = &G_CONST_SHCEMA_TYPE_FORMULA.
											, i_sheet_name = &_excel_sheet_name.
											, ods_output_ds = &_TMP_DS_UNIT_FORMULA_IN_DIR)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUDS.TerminateLoop(_dsid_formula_set)
			%&RSUError.Throw(Error occured during loadin formula definition)
			%return;
		%end;
		%SetFormulaDefinitionId(iods_loaded_formula_def = &_TMP_DS_UNIT_FORMULA_IN_DIR
									, i_formula_set_id = &_formula_set_id.)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to complement formula definition)
			%&RSUDS.TerminateLoop(_dsid_formula_set)
			%return;
		%end;
		%&RSULogger.PutInfo(%&RSUDS.GetCount(&_TMP_DS_UNIT_FORMULA_IN_DIR) formula(s) defined for "&_formula_set_id.".)
		%&RSUDS.Append(iods_base_ds = &_TMP_DS_FULL_FORMULA_IN_DIR.
							, ids_data_ds = &_TMP_DS_UNIT_FORMULA_IN_DIR)
		%&RSUDS.Delete(&_TMP_DS_UNIT_FORMULA_IN_DIR)
	%end;
	/* Overwrite */
	%&DataController.Overwrite(iods_base_ds = &iods_output_ds.
										, ids_data_ds = &_TMP_DS_FULL_FORMULA_IN_DIR.
										, i_by_variables = &G_CONST_VAR_FORM_SYSTEM_ID. &G_CONST_VAR_VARIABLE_REF_NAME.)
	%&RSUDS.Delete(&_TMP_DS_FULL_FORMULA_IN_DIR.)
%mend LoadFormulaDefintion;

%macro SetFormulaDefinitionId(iods_loaded_formula_def =
										, i_formula_set_id = );
	data &iods_loaded_formula_def.;
		set &iods_loaded_formula_def.;
		attrib
			formula_set_id length = $18.
		;
		formula_set_id = "&i_formula_set_id.";
	run;
	quit;
%mend SetFormulaDefinitionId;

/**============================================**/
/* サイズの最小化
/**============================================**/
%macro FormMgr__MinimizeSize(ids_formula_definition =
									, ods_formula_def_minimized =);
	%&RSULogger.PutNote(Minimizing data size...)
	%local _max_len_formula_appl_condition;
	%local _max_len_formula_def_rhs;
	data _null_;
		set &ids_formula_definition.(keep = formula_appl_condition formula_definition_rhs) end = eof;
		retain _max_len_formula_appl_condition 0;
		retain _max_len_formula_def_rhs 0;
		if (_max_len_formula_appl_condition < length(formula_appl_condition)) then do;
			_max_len_formula_appl_condition = length(formula_appl_condition);
		end;
		if (_max_len_formula_def_rhs < length(formula_definition_rhs)) then do;
			_max_len_formula_def_rhs = length(formula_definition_rhs);
		end;
		if (eof) then do;
			call symputx('_max_len_formula_appl_condition', int(_max_len_formula_appl_condition * 1.2));
			call symputx('_max_len_formula_def_rhs', int(_max_len_formula_def_rhs * 1.2));
		end;
	run;
	quit;
	data &ods_formula_def_minimized.(rename = (formula_appl_condition_min = formula_appl_condition formula_definition_rhs_min = formula_definition_rhs));
		set &ids_formula_definition.;
		attrib
			formula_appl_condition_min length = $&_max_len_formula_appl_condition.
			formula_definition_rhs_min length = $&_max_len_formula_def_rhs.
		;
		formula_appl_condition_min = trim(formula_appl_condition);
		formula_definition_rhs_min = trim(formula_definition_rhs);
		drop
			formula_appl_condition
			formula_definition_rhs
		;
	run;
	quit;
%mend FormMgr__MinimizeSize;

/**===================================**/
/* 欠損値補完
/**===================================**/
%macro FormMgr__FillNuallValue(iods_formula_definition =);
	%&RSUDS.ReplaceNullC(iods_input_ds = &iods_formula_definition.
								, i_replaced_vars = formula_appl_condition
								, i_replace_value = %&RSUBool.True)
	%&RSUDS.ReplaceNullC(iods_input_ds = &iods_formula_definition.
								, i_replaced_vars = aggregation_coef
								, i_replace_value = 1)
	%&RSUDS.ReplaceNullC(iods_input_ds = &iods_formula_definition.
								, i_replaced_vars = report_format
								, i_replace_value = BEST.)
	%&RSUDS.ReplaceNullN(iods_input_ds = &iods_formula_definition.
								, i_replaced_vars = scale
								, i_replace_value = 1)
%mend FormMgr__FillNuallValue;

/*===================================*/
/* 読み込み後処理
/*
/* NOTE: 計算設定
/* NOTE: グローバルなパラメータテーブル
/* NOTE: 親子関係
/*===================================*/
%macro FormMgr__PostProcess(iods_formula_def =);
	data &iods_formula_def;
		set &iods_formula_def.;
		attrib
			formula_report_key length = $200.
		;
		formula_order = _N_;
		formula_report_key = &G_CONST_VAR_VARIABLE_REF_NAME.;
		&G_CONST_VAR_VARIABLE_REF_NAME. = cats("&G_CONST_VPR_FUNC_REF.{", catx('!', formula_set_id, &G_CONST_VAR_VARIABLE_REF_NAME.), '}');
	run;
	quit;

	/* 計算設定置換 */
	%&CalculationSetting.SubstituteValueTo(iods_formula_definition = &iods_formula_def.
														, i_target_definition = formula_appl_condition)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to set calculation setting value to formula application condition)
		%return;
	%end;
	%&CalculationSetting.SubstituteValueTo(iods_formula_definition = &iods_formula_def.
														, i_target_definition = formula_definition_rhs)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to set calculation setting value to formula definition)
		%return;
	%end;

	/* グローバルパラメータテーブル */
	/* !todo
	
	/* 親子関係 */
	%SetParentChildNodeRelationShip(iods_loaded_formula_def = &iods_formula_def.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to file child nodes)
		%return;
	%end;

	%ExpandStatisticFunction(iods_formula_definition = &iods_formula_def.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to expand child nodes)
		%return;
	%end;
%mend FormMgr__PostProcess;

/**=============================================**/
/* Formula 定義保存
/*
/* NOTE: 計算設定代入（適用条件、定義）
/* NOTE: 集計関数展開
/**=============================================**/
%macro FormMgr__SaveFormulaDefinition(iods_formula_definition =);
	%&RSULogger.PutSubsection(Formula defintion finalizing)

	proc sort data = &iods_formula_definition.;
		by
			formula_order
		;
	run;
	quit;

	data &iods_formula_definition.;
		format
			formula_set_id
			formula_system_id___
			formula_order
			formula_appl_condition
			variable_ref_name
			formula_definition_rhs
		;
		set &iods_formula_definition.;
	run;
	quit;
	%&RSUDS.Move(i_query = &iods_formula_definition.
					, ods_dest_ds = &G_CONST_DS_FORMULA_DEFINITION.)
%mend FormMgr__SaveFormulaDefinition;

/*--------------------------------------*/
/* 子Formula 統計関数を展開.
/*
/* NOTE: Agg: 集計符号を勘案した合算
/* NOTE: Sum: 和
/* NOTE: Prod: 積
/* NOTE: Avg: 平均
/* NOTE: Max: 最大
/* NOTE: Min: 最小
/* NOTE: Count: 子要素数
/*
/* ! Formula展開前に統計関数を処理するためのアイデア：子供のノードをUniqueにする
/*--------------------------------------*/
%macro ExpandStatisticFunction(iods_formula_definition =);
	%&RSULogger.PutNote(Expanding aggretion function.)
	/* 子ノード候補（formula_parentがあるノード） */
	%local /readonly _TMP_DS_CHILD_NODES = %&RSUDS.GetTempDSName(child_node);
	%&RSUDS.GetUniqueList(i_query = &iods_formula_definition.(where = (not missing(formula_name_parent)))
								, i_by_variables = &G_CONST_VAR_VARIABLE_REF_NAME.
								, ods_output_ds = &_TMP_DS_CHILD_NODES.(keep = formula_name_parent &G_CONST_VAR_VARIABLE_REF_NAME. aggregation_coef))
	data &_TMP_DS_CHILD_NODES.;
		set &_TMP_DS_CHILD_NODES.(where = (not missing(&G_CONST_VAR_VARIABLE_REF_NAME.)));
		rename
			&G_CONST_VAR_VARIABLE_REF_NAME. = &G_CONST_VAR_VARIABLE_REF_NAME._child
			formula_name_parent = &G_CONST_VAR_VARIABLE_REF_NAME.
			aggregation_coef = aggregation_coef_child
		;
	run;
	quit;

	%local /readonly _DECOMP_REGEX_STAT = %&VPRParser.CreateDecompRegex(i_functions = &G_CONST_REGEX_STAT_FUNCTIONS.
																							, i_regex_delimiter = &G_CONST_REGEX_STAT_FUNC_DELM.);
	%local _max_len;
	data &iods_formula_definition(drop = __tmp_decmp: __rc aggregation_coef formula_name_parent &G_CONST_VAR_VARIABLE_REF_NAME._child aggregation_coef_child);
		if (_N_ = 0) then do;
			set 
				&_TMP_DS_CHILD_NODES.
			;
		end;
		set &iods_formula_definition. end = eof;
		attrib
			formula_definition_rhs_long length = $3000.
			__tmp_decmp_definition length = $3000.
			__tmp_decmp_expanded_function length = $3000.
			__tmp_decmp_stat_function length = $100.
		;
		if (_N_ = 1) then do;
			declare hash hh_value(dataset: "&_TMP_DS_CHILD_NODES.", multidata: 'y');
			__rc = hh_value.definekey("&G_CONST_VAR_VARIABLE_REF_NAME.");
			__rc = hh_value.definedata("&G_CONST_VAR_VARIABLE_REF_NAME._child");
			__rc = hh_value.definedata("aggregation_coef_child");
			__rc = hh_value.definedone();
		end;
		__tmp_decmp_regex_formula_ref = prxparse("/&_DECOMP_REGEX_STAT./o");
		__tmp_decmp_definition = cat('`', strip(formula_definition_rhs), '`');
		__tmp_decmp_org_length = lengthn(__tmp_decmp_definition);
		__tmp_decmp_start = 1;
		__tmp_decmp_stop = __tmp_decmp_org_length;
		__tmp_decmp_position = 0;
		__tmp_decmp_length = 0;
		__tmp_decmp_prev_start = 1;
		__tmp_decmp_finished = 0;
		__tmp_decmp_safty_index = 0;
		formula_definition_rhs_long = '';
		retain __tmp_decmp_max_len 0;
		do while(__tmp_decmp_safty_index < 100);
			call prxnext(__tmp_decmp_regex_formula_ref, __tmp_decmp_start, __tmp_decmp_stop, __tmp_decmp_definition, __tmp_decmp_position, __tmp_decmp_length);
			if (__tmp_decmp_position = 0) then do;
				__tmp_decmp_finished = 1;
				__tmp_decmp_position = __tmp_decmp_org_length; 
			end;
			formula_definition_rhs_long = catt(formula_definition_rhs_long, cat('`', substr(__tmp_decmp_definition, __tmp_decmp_prev_start, __tmp_decmp_position - __tmp_decmp_prev_start + 1), '`'));
			if (__tmp_decmp_finished = 1) then do;
				leave;
			end;
			__tmp_decmp_stat_function = prxposn(__tmp_decmp_regex_formula_ref, 1, __tmp_decmp_definition);
			__rc = hh_value.find();
			if (__rc = 0) then do;
				select (__tmp_decmp_stat_function);
					when ('{Agg}') do;
						__tmp_decmp_expanded_function = catt('(', aggregation_coef_child, '*', &G_CONST_VAR_VARIABLE_REF_NAME._child, ')');
						__rc = hh_value.find_next();
						do while(__rc = 0);
							__tmp_decmp_expanded_function = catx('+', __tmp_decmp_expanded_function, catt('(', aggregation_coef_child, '*', &G_CONST_VAR_VARIABLE_REF_NAME._child, ')'));
							__rc = hh_value.find_next();
						end;
					end;
					when ('{Sum}') do;
						__tmp_decmp_expanded_function = catt('sum(', &G_CONST_VAR_VARIABLE_REF_NAME._child);
						__rc = hh_value.find_next();
						do while(__rc = 0);
							__tmp_decmp_expanded_function = catx(',', __tmp_decmp_expanded_function, &G_CONST_VAR_VARIABLE_REF_NAME._child);
							__rc = hh_value.find_next();
						end;
						__tmp_decmp_expanded_function = catt(__tmp_decmp_expanded_function, ')');
					end;
					when ('{Prod}') do;
						__tmp_decmp_expanded_function = catt('(', &G_CONST_VAR_VARIABLE_REF_NAME._child, ')');
						__rc = hh_value.find_next();
						do while(__rc = 0);
							__tmp_decmp_expanded_function = catx('*', catt('(', &G_CONST_VAR_VARIABLE_REF_NAME._child, ')'));
							__rc = hh_value.find_next();
						end;
					end;
					when ('{Avg}') do;
						__tmp_decmp_expanded_function = catt('mean(', &G_CONST_VAR_VARIABLE_REF_NAME._child);
						__rc = hh_value.find_next();
						do while(__rc = 0);
							__tmp_decmp_expanded_function = catx(',', __tmp_decmp_expanded_function, &G_CONST_VAR_VARIABLE_REF_NAME._child);
							__rc = hh_value.find_next();
						end;
						__tmp_decmp_expanded_function = catt(__tmp_decmp_expanded_function, ')');
					end;
					when ('{Max}') do;
						__tmp_decmp_expanded_function = catt('max(', &G_CONST_VAR_VARIABLE_REF_NAME._child);
						__rc = hh_value.find_next();
						do while(__rc = 0);
							__tmp_decmp_expanded_function = catx(',', __tmp_decmp_expanded_function, &G_CONST_VAR_VARIABLE_REF_NAME._child);
							__rc = hh_value.find_next();
						end;
						__tmp_decmp_expanded_function = catt(__tmp_decmp_expanded_function, ')');
					end;
					when ('{Min}') do;
						__tmp_decmp_expanded_function = catt('min(', &G_CONST_VAR_VARIABLE_REF_NAME._child);
						__rc = hh_value.find_next();
						do while(__rc = 0);
							__tmp_decmp_expanded_function = catx(',', __tmp_decmp_expanded_function, &G_CONST_VAR_VARIABLE_REF_NAME._child);
							__rc = hh_value.find_next();
						end;
						__tmp_decmp_expanded_function = catt(__tmp_decmp_expanded_function, ')');
					end;
					when ('{Count}') do;
						__tmp_decmp_expanded_count = 1;
						__rc = hh_value.find_next();
						do while(__rc = 0);
							__tmp_decmp_expanded_count = __tmp_decmp_expanded_count + 1;
							__rc = hh_value.find_next();
						end;
						__tmp_decmp_expanded_function = compress(put(__tmp_decmp_expanded_count, BEST.));
					end;
					otherwise;
				end;
				__tmp_decmp_expanded_function = catt('(', __tmp_decmp_expanded_function, ')');
			end;

			formula_definition_rhs_long = catt(formula_definition_rhs_long, __tmp_decmp_expanded_function);			
			__tmp_decmp_prev_start = __tmp_decmp_position + __tmp_decmp_length;
			__tmp_decmp_safty_index = __tmp_decmp_safty_index + 1;
		end;
		formula_definition_rhs_long = compress(formula_definition_rhs_long, '`');
		if (__tmp_decmp_max_len < length(formula_definition_rhs_long)) then do;
			__tmp_decmp_max_len = length(formula_definition_rhs_long);
		end;
		output;
		if (eof) then do;
			call symputx('_max_len', int(__tmp_decmp_max_len * 1.2));
		end;
	run;
	quit;

	data &iods_formula_definition(drop = formula_definition_rhs_long);
		attrib
			formula_definition_rhs length = $&_max_len.
		;
		set &iods_formula_definition(drop = formula_definition_rhs);
		formula_definition_rhs = formula_definition_rhs_long;
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_CHILD_NODES.)
%mend ExpandStatisticFunction;

%macro SetParentChildNodeRelationShip(iods_loaded_formula_def =);
	%&RSULogger.PutNote(Setting parent-child relationship...)
	data &iods_loaded_formula_def.(drop = __tmp_parent_node_:);
		set &iods_loaded_formula_def.;
		attrib
			formula_name_parent length = $200.
		;
		__tmp_parent_node_regex = prxparse("s/^(&G_CONST_VPR_FUNC_REF.\{[^}]+)(\|[^|]+)\}$/$1}/o");
		if (prxmatch(__tmp_parent_node_regex, trim(&G_CONST_VAR_VARIABLE_REF_NAME.))) then do;
			formula_name_parent = prxchange(__tmp_parent_node_regex, -1, trim(&G_CONST_VAR_VARIABLE_REF_NAME.));
		end;
	run;
	quit;
%mend SetParentChildNodeRelationShip;

/*--------------------------------------*/
/* Model定義 → Formula定義
/*--------------------------------------*/
%macro ConvertModelDefToFormulaDef(ids_model_definition =
											, ods_formula_definition =);
	data &ods_formula_definition.;
		if (_N_ = 0) then do;
			set &G_CONST_DS_FORMULA_DEFINITION.;
		end;
		attrib
			formula_set_id length = $18.
			formula_definition_id length = $1000.
		;
		set &ids_model_definition.;
		&G_CONST_VAR_FORM_SYSTEM_ID. = '';
		&G_CONST_VAR_VARIABLE_REF_NAME. = model_id;
		formula_appl_condition = '1';
		formula_definition_rhs = model_definition;
		aggregation_coef = '';
		is_hidden = '';
		report_format = 'BEST.';
		scale = 1;
		formula_set_id = 'MODEL_EVALUATION';
		formula_definition_id = model_id;
		keep
			&G_CONST_VAR_FORM_SYSTEM_ID.
			&G_CONST_VAR_VARIABLE_REF_NAME.
			formula_appl_condition
			formula_definition_rhs
			aggregation_coef
			is_hidden
			report_format
			scale
			formula_set_id
			formula_definition_id
		;
	run;
%mend ConvertModelDefToFormulaDef;

%macro FormMgr__FormulaResult(i_formula_set_id =);
	&G_CONST_LIB_RSLT..result_&i_formula_set_id.
%mend FormMgr__FormulaResult;

%macro FormMgr__MergeModelAndFormula(iods_formula_definition =
												, ids_model_definition =);
	/* Reshape */
	%ConvertModelDefToFormulaDef(ids_model_definition = &ids_model_definition.
										, ods_formula_definition = WORK.tmp_converted_model_def)
	%&RSUDS.Append(iods_base_ds = &iods_formula_definition.
						, ids_data_ds = WORK.tmp_converted_model_def)
	%&RSUDS.Delete(WORK.tmp_converted_model_def)
%mend FormMgr__MergeModelAndFormula;
