/***********************************************************/
/* FormulaEncoder.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***********************************************************/
%RSUSetConstant(FormulaEncoder, FormEnc__)

/**==============================**/
/* 関数のコード化
/**==============================**/
%macro FormEnc__ReformAndCreateRefVars(iods_formula_def =);
	/* 数式変数をコードに変換 */
	%local /readonly _TMP_DS_FUNCTION_LIST = %&RSUDS.GetTempDSName(vpr_functions);
	%&RSUDS.GetUniqueList(i_query = &G_CONST_DS_EXTERNAL_DATA_LIST.(keep = ref_function_name where = (ref_function_name ne "&G_CONST_VPR_FUNC_REF."))
								, i_by_variables = ref_function_name
								, ods_output_ds = &_TMP_DS_FUNCTION_LIST.)
	%local _vpr_function_list;
	%local _ref_function_name;
	%local _dsid_data_id;
	%do %while(%&RSUDS.ForEach(i_query = &_TMP_DS_FUNCTION_LIST.
										, i_vars = _ref_function_name:ref_function_name
										, ovar_dsid = _dsid_data_id));
		%&RSUText.Append(iovar_base =  _vpr_function_list
							, i_append_text = (&_ref_function_name.)
							, i_delimiter = |)
	%end;
	%local /readonly _NO_OF_VPR_FUNCTIONS = %&RSUDS.GetCount(&_TMP_DS_FUNCTION_LIST.);
	%&RSUDS.Delete(&_TMP_DS_FUNCTION_LIST.)
	%ReformFunctionOther(iods_formula_definition = &iods_formula_def.
								, i_target_variable = formula_appl_condition
								, i_regex_functions = &_vpr_function_list.
								, i_no_of_functions = &_NO_OF_VPR_FUNCTIONS.)
	%ReformFunctionOther(iods_formula_definition = &iods_formula_def.
								, i_target_variable = formula_definition_rhs
								, i_regex_functions = &_vpr_function_list.
								, i_no_of_functions = &_NO_OF_VPR_FUNCTIONS.)
	%local /readonly _TMP_DS_REF_VARS = %&RSUDS.GetTempDSName(ref_vars);
	%local /readonly _TMP_DS_REF_VARS_IN_DEF = %&RSUDS.GetTempDSName(ref_vars_in_def);
	%ReformAndCollectFunctionRef(iods_formula_definition = &iods_formula_def.
										, i_target_variable = formula_appl_condition
										, ods_variable_list = &_TMP_DS_REF_VARS_IN_DEF.)
	%&RSUDS.Append(iods_base_ds = &_TMP_DS_REF_VARS.
						, ids_data_ds = &_TMP_DS_REF_VARS_IN_DEF.)
	%&RSUDS.Delete(&_TMP_DS_REF_VARS_IN_DEF.)

	%ReformAndCollectFunctionRef(iods_formula_definition = &iods_formula_def.
										, i_target_variable = formula_definition_rhs
										, ods_variable_list = &_TMP_DS_REF_VARS_IN_DEF.)
	%&RSUDS.Append(iods_base_ds = &_TMP_DS_REF_VARS.
						, ids_data_ds = &_TMP_DS_REF_VARS_IN_DEF.)
	%&RSUDS.Delete(&_TMP_DS_REF_VARS_IN_DEF.)

	%ReformAndCollectFunctionRef(iods_formula_definition = &iods_formula_def.
										, i_target_variable = &G_CONST_VAR_VARIABLE_REF_NAME.
										, ods_variable_list = &_TMP_DS_REF_VARS_IN_DEF.)
	%&RSUDS.Append(iods_base_ds = &_TMP_DS_REF_VARS.
						, ids_data_ds = &_TMP_DS_REF_VARS_IN_DEF.)
	%&RSUDS.Delete(&_TMP_DS_REF_VARS_IN_DEF.)

	/* Variable Code */
	%&RSUDS.Let(i_query = &_TMP_DS_REF_VARS.(rename = variable_ref = &G_CONST_VAR_VARIABLE_REF_NAME.)
					, ods_dest_ds = &_TMP_DS_REF_VARS.)
	%&VariableEncoder.EncodeRefVariable(ids_vairable_list = &_TMP_DS_REF_VARS.)
	%&RSUDS.Delete(&_TMP_DS_REF_VARS.)
%mend FormEnc__ReformAndCreateRefVars;

/**===============================**/
/* Formula をコード化
/**===============================**/
%macro FormEnc__Encode(iods_formula_def =);
	%&RSULogger.PutNote(Encoding vairables in formula with variable code)
	%local /readonly _TMP_DS_FUNCTION_LIST = %&RSUDS.GetTempDSName(vpr_functions);
	%&RSUDS.GetUniqueList(i_query = &G_CONST_DS_EXTERNAL_DATA_LIST.(keep = ref_function_name)
								, i_by_variables = ref_function_name
								, ods_output_ds = &_TMP_DS_FUNCTION_LIST.)
	%local _vpr_function_list;
	%local _ref_function_name;
	%local _dsid_data_id;
	%do %while(%&RSUDS.ForEach(i_query = &_TMP_DS_FUNCTION_LIST.
										, i_vars = _ref_function_name:ref_function_name
										, ovar_dsid = _dsid_data_id));
		%&RSUText.Append(iovar_base =  _vpr_function_list
							, i_append_text = (&_ref_function_name.)
							, i_delimiter = |)
	%end;

	%local _data_index;
	%local _dsid_data_id;
	%local /readonly _TMP_DS_VARIABLE_CODE_LIST = %&RSUDS.GetTempDSName(variable_code_list);
	%do %while(%&RSUDS.ForEach(i_query = &G_CONST_DS_EXTERNAL_DATA_LIST.
										, i_vars = _data_index:data_index
										, ovar_dsid = _dsid_data_id));
		%&RSUDS.Concat(iods_base_ds = &_TMP_DS_VARIABLE_CODE_LIST.
							, ids_data_ds = %DSVarList(i_data_index = &_data_index.))
	%end;
	%&RSUDS.Let(i_query = &_TMP_DS_VARIABLE_CODE_LIST.(rename = (variable_code = __tmp_parse_variable_code &G_CONST_VAR_VARIABLE_REF_NAME. = __tmp_parse_function_name))
					, ods_dest_ds = &_TMP_DS_VARIABLE_CODE_LIST.)
	%local /readonly _NO_OF_REPLACING_VARS = %&RSUDS.GetCount(&_TMP_DS_FUNCTION_LIST.);
	%ReplaceVariableByCode(iods_formula_definition = &iods_formula_def.
								, i_target_variable = formula_appl_condition
								, i_regex_functions = &_vpr_function_list.
								, i_no_of_functions = &_NO_OF_REPLACING_VARS.
								, iods_replacing_variable_code = &_TMP_DS_VARIABLE_CODE_LIST.)
	%ReplaceVariableByCode(iods_formula_definition = &iods_formula_def.
								, i_target_variable = formula_definition_rhs
								, i_regex_functions = &_vpr_function_list.
								, i_no_of_functions = &_NO_OF_REPLACING_VARS.
								, iods_replacing_variable_code = &_TMP_DS_VARIABLE_CODE_LIST.)
	%ReplaceVariableByCode(iods_formula_definition = &iods_formula_def.
								, i_target_variable = &G_CONST_VAR_VARIABLE_REF_NAME.
								, i_regex_functions = &_vpr_function_list.
								, i_no_of_functions = &_NO_OF_REPLACING_VARS.
								, iods_replacing_variable_code = &_TMP_DS_VARIABLE_CODE_LIST.)
	%&RSUDS.Delete(&_TMP_DS_VARIABLE_CODE_LIST. &_TMP_DS_FUNCTION_LIST.)
%mend FormEnc__Encode;

/*----------------------------------------*/
/* Ref 以外の関数を変形
/* ! 入力データとの参照整合もここでいける
/*----------------------------------------*/
%macro ReformFunctionOther(iods_formula_definition =
									, i_target_variable =
									, i_regex_functions =
									, i_no_of_functions =);
	%&RSULogger.PutNote(Reforming input data refering functions)
	%&RSULogger.PutInfo(Regular expression: &i_regex_functions.)
	/* variables in rhs */	
	%local /readonly _TIME_DIGIT = %&CalculationSetting.Get(i_key = time_digit);
	data &iods_formula_definition.(drop = __tmp_parse_:);
		set &iods_formula_definition. end = eof;
		attrib
			__tmp_parse_formula_def_original length = $3000.
			__tmp_parse_non_function_part length = $3000.
			__tmp_parse_function_part length = $100.
			__tmp_parse_function_name length = $50.
			__tmp_parse_function_arg length = $100.
			__tmp_parse_time_specifier length = $8.
		;
		__tmp_parse_regex_formula_ref = prxparse("/(&G_CONST_REGEX_VPR_FUNC_DELM.)(&i_regex_functions.)\{([^\}@]+)(@((\d{&_TIME_DIGIT.})|(-\d+)))?\}/o");
		__tmp_parse_formula_def_original = cat('`', strip(&i_target_variable.), '`');
		__tmp_parse_org_length = lengthn(__tmp_parse_formula_def_original);
		__tmp_parse_start = 1;
		__tmp_parse_stop = __tmp_parse_org_length;
		__tmp_parse_position = 0;
		__tmp_parse_length = 0;
		__tmp_parse_prev_start = 1;
		__tmp_parse_finished = 0;
		__tmp_parse_safty_index = 0;
		&i_target_variable. = '';
		do while(__tmp_parse_safty_index < 30);
			call prxnext(__tmp_parse_regex_formula_ref, __tmp_parse_start, __tmp_parse_stop, __tmp_parse_formula_def_original, __tmp_parse_position, __tmp_parse_length);
			if (__tmp_parse_position = 0) then do;
				__tmp_parse_finished = 1;
				__tmp_parse_position = __tmp_parse_org_length; 
			end;
			__tmp_parse_non_function_part = cat('`', substr(__tmp_parse_formula_def_original, __tmp_parse_prev_start, __tmp_parse_position - __tmp_parse_prev_start + 1), '`');

			if (__tmp_parse_finished = 1) then do;
				&i_target_variable. = catt(&i_target_variable., __tmp_parse_non_function_part); 
				leave;
			end;

			__tmp_parse_function_name = prxposn(__tmp_parse_regex_formula_ref, 2, __tmp_parse_formula_def_original);
			__tmp_parse_function_arg = prxposn(__tmp_parse_regex_formula_ref, &i_no_of_functions. + 3, __tmp_parse_formula_def_original);
			__tmp_parse_time_specifier = prxposn(__tmp_parse_regex_formula_ref, &i_no_of_functions. + 5, __tmp_parse_formula_def_original);
			__tmp_parse_function_part = cats(__tmp_parse_function_name
													, cats('{', __tmp_parse_function_arg, '}')
													, cats('{', __tmp_parse_time_specifier, '}'));
			/* reform */
			&i_target_variable. = catt(&i_target_variable.
												, __tmp_parse_non_function_part
												, __tmp_parse_function_part);

			__tmp_parse_prev_start = __tmp_parse_position + __tmp_parse_length;
			__tmp_parse_safty_index = __tmp_parse_safty_index + 1;
		end;
		&i_target_variable. = compress(&i_target_variable., '`');
		output;
	run;
	quit;
%mend ReformFunctionOther;

/*-----------------------------------------------------*/
/* Ref変数の収集
/*
/* ! コードの節約, 時間の節約のためにここで一気にやる
/*-----------------------------------------------------*/
%macro ReformAndCollectFunctionRef(iods_formula_definition =
											, i_target_variable =
											, ods_variable_list =);
	%&RSULogger.PutNote(Defining formula variables in &i_target_variable.)
	%local /readonly _TMP_CONFIG_AGGREGATION = %&RSUDS.GetTempDSName(conf_aggregation);
	data &_TMP_CONFIG_AGGREGATION.;
		set &G_SETTING_CONFIG_DS_RESULT_AGGR.(keep = formula_set_id aggregation_method data_id_output);
		rename
			formula_set_id = __agg_formula_set_id
			aggregation_method = __agg_aggregation_method
			data_id_output = __agg_data_id_output
		;
	run;
	quit;

	%local /readonly _TIME_DIGIT = %&CalculationSetting.Get(i_key = time_digit);
	%local /readonly _TMP_DS_VARIABLES = %&RSUDS.GetTempDSName(variables);
	%local /readonly _NO_OF_VPR_FUNCTION = 1;
	data &iods_formula_definition.(drop = __tmp_parse: data_id variable_ref __agg_:);
		set &iods_formula_definition. end = eof;
		attrib
			__tmp_parse_formula_def_original length = $3000.
			__tmp_parse_non_function_part length = $3000.
			__tmp_parse_function_part length = $100.
			__tmp_parse_function_name length = $50.
			__tmp_parse_function_arg length = $100.
			__tmp_parse_time_specifier length = $8.
			__tmp_parse_formula_group length = $32.

			__agg_formula_set_id length = $18.
			__agg_aggregation_method length = $50.
			__agg_data_id_output length = $18.

			data_id length = $18.
			variable_ref length = $200.
		;
		if (_N_ = 1) then do;
			__tmp_parse_formula_set_id_dsid = open("&G_SETTING_CONFIG_DS_FORMULA_DEF.", 'I');

			declare hash hh_variable_in_rhs();
			__tmp_parse_rc = hh_variable_in_rhs.definekey("data_id");
			__tmp_parse_rc = hh_variable_in_rhs.definekey("variable_ref");
			__tmp_parse_rc = hh_variable_in_rhs.definedone();

			declare hash hh_aggregation(dataset: "&_TMP_CONFIG_AGGREGATION.");
			__tmp_parse_rc = hh_aggregation.definekey('__agg_formula_set_id');
			__tmp_parse_rc = hh_aggregation.definekey('__agg_aggregation_method');
			__tmp_parse_rc = hh_aggregation.definedata('__agg_data_id_output');
			__tmp_parse_rc = hh_aggregation.definedone();
		end;
		__tmp_parse_regex_formula_ref = prxparse("/(&G_CONST_REGEX_VPR_FUNC_DELM.)((&G_CONST_VPR_FUNC_REF.))\{([^\}@]+)(@((\d{&_TIME_DIGIT.})|(-\d+)))?\}/o");
		__tmp_parse_formula_def_original = cat('`', strip(&i_target_variable.), '`');
		__tmp_parse_org_length = lengthn(__tmp_parse_formula_def_original);
		__tmp_parse_start = 1;
		__tmp_parse_stop = __tmp_parse_org_length;
		__tmp_parse_position = 0;
		__tmp_parse_length = 0;
		__tmp_parse_prev_start = 1;
		__tmp_parse_finished = 0;
		__tmp_parse_safty_index = 0;
		&i_target_variable. = '';
		retain __tmp_parse_formula_set_id_dsid;
		do while(__tmp_parse_safty_index < 30);
			call prxnext(__tmp_parse_regex_formula_ref, __tmp_parse_start, __tmp_parse_stop, __tmp_parse_formula_def_original, __tmp_parse_position, __tmp_parse_length);
			if (__tmp_parse_position = 0) then do;
				__tmp_parse_finished = 1;
				__tmp_parse_position = __tmp_parse_org_length; 
			end;
			__tmp_parse_non_function_part = cat('`', substr(__tmp_parse_formula_def_original, __tmp_parse_prev_start, __tmp_parse_position - __tmp_parse_prev_start + 1), '`');

			if (__tmp_parse_finished = 1) then do;
				&i_target_variable. = catt(&i_target_variable., __tmp_parse_non_function_part); 
				leave;
			end;

			__tmp_parse_function_arg = prxposn(__tmp_parse_regex_formula_ref, &_NO_OF_VPR_FUNCTION. + 3, __tmp_parse_formula_def_original);
			__tmp_parse_time_specifier = prxposn(__tmp_parse_regex_formula_ref, &_NO_OF_VPR_FUNCTION. + 5, __tmp_parse_formula_def_original);
			/* argument の解析 */
			/* '!'の存在 */
			/* '***Of:'の存在 (**Of:がある場合は必ず '!'がある）*/
			if (find(__tmp_parse_function_arg, '!') = 0) then do;
				__tmp_parse_formula_group = formula_set_id;
				__agg_aggregation_method = '';
			end;
			else do;
				__tmp_parse_formula_group = scan(__tmp_parse_function_arg, 1, '!');
				if (find(__tmp_parse_formula_group, ':') ne 0) then do;
					__agg_aggregation_method = scan(__tmp_parse_formula_group, 1, 'Of:');
					__tmp_parse_formula_group = scan(__tmp_parse_formula_group, 2, ':');
				end;
				else do;
					__agg_aggregation_method = '';
				end;

				/* エクセルシートの指定をFormulaグループに変換 */
				__tmp_parse_rc = rewind(__tmp_parse_formula_set_id_dsid);
				__tmp_parse_rc = fetch(__tmp_parse_formula_set_id_dsid);
				do while(__tmp_parse_rc = 0);
					__tmp_parse_regex = cats('/', getvarc(__tmp_parse_formula_set_id_dsid, 2), '/');
					if (prxmatch(__tmp_parse_regex, trim(__tmp_parse_formula_group))) then do;
						__tmp_parse_formula_group = getvarc(__tmp_parse_formula_set_id_dsid, 1);
						leave;
					end;
					__tmp_parse_rc = fetch(__tmp_parse_formula_set_id_dsid);
				end;
				/* Aggregation */
				if (not missing(__agg_aggregation_method)) then do;
					__agg_formula_set_id = __tmp_parse_formula_group;
					__tmp_parse_rc = hh_aggregation.find();
					__tmp_parse_formula_group = __agg_data_id_output;
				end;
				/* Aggregationの情報を付与 */
				__tmp_parse_function_arg = catx('_', __agg_aggregation_method, scan(__tmp_parse_function_arg, 2, '!'));
			end;
			data_id = __tmp_parse_formula_group;
			variable_ref = cats("&G_CONST_VPR_FUNC_REF."
										, '{', catx('!', __tmp_parse_formula_group, __tmp_parse_function_arg), '}');
			__tmp_parse_function_part = cats(variable_ref
													, cats('{', __tmp_parse_time_specifier, '}'));
			/* reform */
			&i_target_variable. = catt(&i_target_variable.
												, __tmp_parse_non_function_part
												, __tmp_parse_function_part);

			__tmp_parse_rc = hh_variable_in_rhs.add();
			__tmp_parse_prev_start = __tmp_parse_position + __tmp_parse_length;
			__tmp_parse_safty_index = __tmp_parse_safty_index + 1;
		end;
		&i_target_variable. = compress(&i_target_variable., '`');
		output;
		if (eof) then do;
			__tmp_parse_rc = close(__tmp_parse_formula_set_id_dsid);
			__tmp_parse_rc = hh_variable_in_rhs.output(dataset: "&ods_variable_list.");
		end;
	run;
	quit;
%mend ReformAndCollectFunctionRef;

/*----------------------------------------*/
/* Ref 以外の関数を変形
/* ! 入力データとの参照整合もここでいける
/*----------------------------------------*/
%macro ReplaceVariableByCode(iods_formula_definition =
									, i_target_variable =
									, i_regex_functions =
									, i_no_of_functions =
									, iods_replacing_variable_code =);
	%&RSULogger.PutNote(Replaceing variable name with variable code)
	%&RSULogger.PutInfo(Regular expression: &i_regex_functions.)
	/* variables in rhs */	
	%local /readonly _TIME_DIGIT = %&CalculationSetting.Get(i_key = time_digit);
	data &iods_formula_definition.(drop = __tmp_parse_:);
		if (_N_ = 0) then do;
			set &iods_replacing_variable_code.;
		end;
		set &iods_formula_definition. end = eof;
		if (_N_ = 1) then do;
			declare hash hh_replace_code(dataset: "&iods_replacing_variable_code.");
			__tmp_parse_rc = hh_replace_code.definekey('__tmp_parse_function_name');
			__tmp_parse_rc = hh_replace_code.definedata('__tmp_parse_variable_code');
			__tmp_parse_rc = hh_replace_code.definedone();
		end;
		attrib
			__tmp_parse_formula_def_original length = $3000.
			__tmp_parse_non_function_part length = $3000.
			__tmp_parse_function_part length = $100.
			__tmp_parse_time_specifier length = $8.
			__tmp_parse_time_dim_pattern_id length = $2.
		;
		__tmp_parse_regex_formula_ref = prxparse("/(&G_CONST_REGEX_VPR_FUNC_DELM.)((&i_regex_functions.)\{[^\}]+\})\{((\d{&_TIME_DIGIT.})|(-\d+))?\}/o");
		__tmp_parse_formula_def_original = cat('`', strip(&i_target_variable.), '`');
		__tmp_parse_org_length = lengthn(__tmp_parse_formula_def_original);
		__tmp_parse_start = 1;
		__tmp_parse_stop = __tmp_parse_org_length;
		__tmp_parse_position = 0;
		__tmp_parse_length = 0;
		__tmp_parse_prev_start = 1;
		__tmp_parse_finished = 0;
		__tmp_parse_safty_index = 0;
		&i_target_variable. = '';
		do while(__tmp_parse_safty_index < 30);
			call prxnext(__tmp_parse_regex_formula_ref, __tmp_parse_start, __tmp_parse_stop, __tmp_parse_formula_def_original, __tmp_parse_position, __tmp_parse_length);
			if (__tmp_parse_position = 0) then do;
				__tmp_parse_finished = 1;
				__tmp_parse_position = __tmp_parse_org_length; 
			end;
			__tmp_parse_non_function_part = cat('`', substr(__tmp_parse_formula_def_original, __tmp_parse_prev_start, __tmp_parse_position - __tmp_parse_prev_start + 1), '`');

			if (__tmp_parse_finished = 1) then do;
				&i_target_variable. = catt(&i_target_variable., __tmp_parse_non_function_part); 
				leave;
			end;

			__tmp_parse_function_name = prxposn(__tmp_parse_regex_formula_ref, 2, __tmp_parse_formula_def_original);
			__tmp_parse_time_specifier = prxposn(__tmp_parse_regex_formula_ref, &i_no_of_functions. + 4, __tmp_parse_formula_def_original);
			__tmp_parse_rc = hh_replace_code.find();
			__tmp_parse_time_dim_pattern_id = substr(__tmp_parse_variable_code, 1, 2);
			__tmp_parse_function_part = cats('{', __tmp_parse_time_dim_pattern_id, '}'
													, '{', __tmp_parse_variable_code, '}'
													, '{', __tmp_parse_time_specifier, '}');

			/* reform */
			&i_target_variable. = catt(&i_target_variable.
												, __tmp_parse_non_function_part
												, __tmp_parse_function_part);

			__tmp_parse_prev_start = __tmp_parse_position + __tmp_parse_length;
			__tmp_parse_safty_index = __tmp_parse_safty_index + 1;
		end;
		&i_target_variable. = compress(&i_target_variable., '`');
		output;
	run;
	quit;
%mend ReplaceVariableByCode;
