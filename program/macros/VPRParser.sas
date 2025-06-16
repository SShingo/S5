/***********************************************************/
/* VPRParser.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***********************************************************/
%RSUSetConstant(VPRParser, VPRParser__)

/**====================================**/
/* Formula分解用のVPR 関数リスト取得
/**====================================**/
%macro VPRParser__FindVPRFunctions(i_formula_set_id =
											, i_extra_functions =
											, ovar_vpr_functions =
											, ovar_no_of_functions =);
	%local /readonly _TMP_DS_FORMULA_EVAL = %&RSUDS.GetTempDSName(formula_eval);
	%&RSUDS.Let(i_query = &G_SETTING_CONFIG_DS_FORMULA_EVAL.(where = (formula_set_id = "&i_formula_set_id."))
					, ods_dest_ds = &_TMP_DS_FORMULA_EVAL.)
	%local /readonly _TMP_DS_LOADING_DATA = %&RSUDS.GetTempDSName(loading_data);
	%&RSUDS.Let(i_query = &G_SETTING_CONFIG_DS_LOADING_DATA.(keep = data_id ref_function_name)
					, ods_dest_ds = &_TMP_DS_LOADING_DATA.)
	%&RSUDS.InnerJoin(ids_lhs_ds = &_TMP_DS_LOADING_DATA.
							, ids_rhs_ds = &_TMP_DS_FORMULA_EVAL.
							, i_conditions = data_id:data_id)
	%&RSUDS.Delete(&_TMP_DS_FORMULA_EVAL.)
	%let &ovar_no_of_functions. = 0;

	%local _ref_function_name;
	%local _dsid_ref_function_name;
	%let &ovar_vpr_functions. =;
	%do %while(%&RSUDS.ForEach(i_query = &_TMP_DS_LOADING_DATA.
										, i_vars = _ref_function_name:ref_function_name
										, ovar_dsid = _dsid_ref_function_name));
		%&RSUText.Append(iovar_base = &ovar_vpr_functions.
							, i_append_text = &_ref_function_name.)
		%let &ovar_no_of_functions. = %eval(&&&ovar_no_of_functions. + 1);
	%end;
	%&RSUDS.Delete(&_TMP_DS_LOADING_DATA.)
	%if (not %&RSUUtil.IsMacroBlank(i_extra_functions)) %then %do;
		%local _index_ref_function_name;
		%do %while(%&RSUUtil.ForEach(i_items = &i_extra_functions.
											, ovar_item = _ref_function_name
											, iovar_index = _index_ref_function_name));
			%&RSUText.Append(iovar_base = &ovar_vpr_functions.
								, i_append_text = &_ref_function_name.)
			%let &ovar_no_of_functions. = %eval(&&&ovar_no_of_functions. + 1);
		%end;
	%end;
%mend VPRParser__FindVPRFunctions;

/**====================================**/
/* Formula分解用の正規表現取得
/**====================================**/
%macro VPRParser__CreateDecompRegex(i_functions =
												, i_regex_delimiter =
												, i_regex_argument =);
	%local _function;
	%local _index_function;
	%local _decomposing_regex;
	%do %while(%&RSUUtil.ForEach(i_items = &i_functions.
										, ovar_item = _function
										, iovar_index = _index_function));
		%&RSUText.Append(iovar_base = _decomposing_regex
							, i_append_text = (&_function.)
							, i_delimiter = |)
	%end;
	%let _decomposing_regex = (&_decomposing_regex.);
	%if (not %&RSUUtil.IsMacroBlank(i_regex_delimiter)) %then %do;
		%let _decomposing_regex = &G_CONST_REGEX_VPR_FUNC_DELM.&_decomposing_regex.;
	%end;
	%if (not %&RSUUtil.IsMacroBlank(i_regex_argument)) %then %do;
		%let _decomposing_regex = &_decomposing_regex.&G_CONST_REGEX_VPR_FUNC_ARGUMENT.;
	%end;
	%local /readonly _TIME_DIGIT = %&CalculationSetting.Get(i_key = time_digit);
	%let _decomposing_regex = %sysfunc(tranwrd(&_decomposing_regex, <TIME_DIGIT>, &_TIME_DIGIT.));
	%&RSULogger.PutInfo(Regular expression: &_decomposing_regex.)
	&_decomposing_regex.
%mend VPRParser__CreateDecompRegex;
