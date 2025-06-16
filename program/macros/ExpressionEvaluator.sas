/***********************************************************************************/
/* ExpressionEvaluator.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: 式の分解
/* NOTE: 式の再構成
/* NOTE: 式の評価
/* NOTE: 評価済み値の代入
/*
/* ! 入れ子になった数式の解釈は未対応
/* ! 今の仕組みで実現は容易（パフォーマンスの問題でやってない）
/*
/***********************************************************************************/
%RSUSetConstant(ExpressionEvaluator, ExprEvl__)
%RSUSetConstant(G_EXPR_EVAL_GROUP_SIZE, 1000)	/* ! "1000"という数字に根拠はないが、なんとなくこれくらいが一番いい感じ */

/**============================================**/
/* 式評価（超高速）
/**============================================**/
%macro ExprEvl__EvaluateExpression(ids_expressions =
											, i_variable_name_expr_id =
											, i_variable_target_expr =
											, i_variable_name_value =
											, ods_evaluated_expression =);
	%local /readonly _TMP_DS_SOURCE_EXPR = %&RSUDS.GetTempDSName(original_expr);
	%&RSUDS.Let(i_query = &ids_expressions.(keep = &i_variable_name_expr_id. &i_variable_target_expr.)
					, ods_dest_ds =  &_TMP_DS_SOURCE_EXPR.)
	%local /readonly _TMP_DS_EVALUATED_EXPR_ACC = %&RSUDS.GetTempDSName(evaluated_expr_acc);
	%local /readonly _TMP_DS_EVALUATED_EXPR = %&RSUDS.GetTempDSName(evaluated_expr);
	%local _group_index;
	data &_TMP_DS_EVALUATED_EXPR_ACC.;
		attrib
			&i_variable_name_expr_id. length = 8.
			&i_variable_name_value. length = $32.
		;
		stop;
	run;
	quit;
	data _null_;
		_dsid = open("&_TMP_DS_SOURCE_EXPR.", 'I');
		_rc = fetch(_dsid);
		_pos_variable_exp_id = varnum(_dsid, "&i_variable_name_expr_id.");
		_pos_variable_expr = varnum(_dsid, "&i_variable_target_expr.");
		_evaluation_count = 0;
		_exec_flg = mod(_evaluation_count, &G_EXPR_EVAL_GROUP_SIZE.);
		do while(_rc = 0);
			if (_exec_flg = 0) then do;
				call execute("data &_TMP_DS_EVALUATED_EXPR.(keep = &i_variable_name_expr_id. &i_variable_name_value.); attrib &i_variable_name_value. length = $32.;");
			end;
			call execute(cats("&i_variable_name_expr_id. = ", getvarn(_dsid, _pos_variable_exp_id), "; &i_variable_name_value. = compress(put(", getvarc(_dsid, _pos_variable_expr), ', BEST.)); output;'));
			_rc = fetch(_dsid);
			_evaluation_count = _evaluation_count + 1;
			_exec_flg = mod(_evaluation_count, &G_EXPR_EVAL_GROUP_SIZE.);
			if (_exec_flg = 0 or _rc ne 0) then do;
				call execute("run; quit; proc append base = &_TMP_DS_EVALUATED_EXPR_ACC. data = &_TMP_DS_EVALUATED_EXPR.; run; quit;");
			end;
		end;
		_rc = close(_dsid);
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_EVALUATED_EXPR.)
	data &ods_evaluated_expression.(drop = _rc);
		if (_N_ = 0) then do;
			set &_TMP_DS_EVALUATED_EXPR_ACC.;
		end;
		set &ids_expressions.(drop = &i_variable_target_expr.);
		if (_N_ = 1) then do;
			declare hash hh_subst(dataset: "&_TMP_DS_EVALUATED_EXPR_ACC.");
			_rc = hh_subst.definekey("&i_variable_name_expr_id.");
			_rc = hh_subst.definedata("&i_variable_name_value.");
			_rc = hh_subst.definedone();
		end;
		_rc = hh_subst.find();
		if (_rc = 0) then do;
			output;
		end;
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_SOURCE_EXPR. &_TMP_DS_EVALUATED_EXPR_ACC.)
%mend ExprEvl__EvaluateExpression;

/**====================================================================*/
/* 式評価
/*
/* NOTE: 通常バージョン（高速）
/**====================================================================*/
%macro ExprEvl__EvaluateExpression_Hi(ids_evaluable_expression =
												, i_evaluated_expression_variable =
												, i_variable_name_value =
												, ods_evaluation_result =);
	%local /readonly _TMP_DS_ORGINAL_EXPR = %&RSUDS.GetTempDSName(original_expr);
	%&RSUDS.Let(i_query = &ids_evaluable_expression.
					, ods_dest_ds =  &_TMP_DS_ORGINAL_EXPR.)
	%&RSUDS.AddSequenceVariable(i_query = &_TMP_DS_ORGINAL_EXPR.
										, i_sequence_variable_name = _evaluable_expression_id)

	%local /readonly _TMP_DS_EVALUABLE_EXPR = %&RSUDS.GetTempDSName(evaluable_expr);
	%&RSUDS.Let(i_query = &_TMP_DS_ORGINAL_EXPR.
					, ods_dest_ds =  &_TMP_DS_EVALUABLE_EXPR.)
	%local _max_group;
	%GroupEvaluatingExpressions(iods_expressions = &_TMP_DS_EVALUABLE_EXPR.
										, i_evaluated_expression_variable = &i_evaluated_expression_variable.
										, i_variable_name_group = _evaluating_group
										, i_variable_name_expr_id = _evaluable_expression_id
										, i_group_size = &G_EXPR_EVAL_GROUP_SIZE.
										, ovar_max_group = _max_group)
	%local /readonly _TMP_DS_EVALUATED_EXPR_ACC = %&RSUDS.GetTempDSName(evaluated_expr);
	%EvaluateExpressionHelper(ids_expressions = &_TMP_DS_EVALUABLE_EXPR.
									, i_variable_name_group = _evaluating_group
									, i_variable_name_expr_id = _evaluable_expression_id
									, i_variable_name_value = &i_variable_name_value.
									, ods_evaluated_expression = &_TMP_DS_EVALUATED_EXPR_ACC.
									, i_max_group = &_max_group.)
	data &ods_evaluation_result.(drop = _rc _evaluable_expression_id &i_evaluated_expression_variable.);
		set &_TMP_DS_ORGINAL_EXPR.;
		attrib
			&i_variable_name_value. length = $100.
		;
		if (_N_ = 1) then do;
			declare hash hh_subst(dataset: "&_TMP_DS_EVALUATED_EXPR_ACC.");
			_rc = hh_subst.definekey('_evaluable_expression_id');
			_rc = hh_subst.definedata("&i_variable_name_value.");
			_rc = hh_subst.definedone();
		end;
		_rc = hh_subst.find();
	run;
	quit;
	%&RSULogger.PutInfo(%&RSUDS.GetCount(&ods_evaluation_result.) formulas evaluated.)
	%&RSUDS.Delete(&_TMP_DS_EVALUABLE_EXPR. &_TMP_DS_EVALUATED_EXPR_ACC. &_TMP_DS_ORGINAL_EXPR.)
%mend ExprEvl__EvaluateExpression_Hi;

%macro GroupEvaluatingExpressions(iods_expressions =
											, i_evaluated_expression_variable =
											, i_variable_name_group =
											, i_variable_name_expr_id =
											, i_group_size =
											, ovar_max_group =);
	data &iods_expressions.;
		format
			&i_evaluated_expression_variable.
			&i_variable_name_expr_id.
			&i_variable_name_group.
		;
		set &iods_expressions. end = eof;
		&i_variable_name_group. = int((&i_variable_name_expr_id. - 1) / &i_group_size.);
		if (eof) then do;
			call symputx("&ovar_max_group.", &i_variable_name_group.);
		end;
		keep
			&i_evaluated_expression_variable.
			&i_variable_name_expr_id.
			&i_variable_name_group.
		;
	run;
	quit;
%mend GroupEvaluatingExpressions;

%macro EvaluateExpressionHelper(ids_expressions =
										, i_variable_name_group =
										, i_variable_name_expr_id =
										, i_variable_name_value =
										, ods_evaluated_expression =
										, i_max_group =);
	%&RSUDS.Delete(&ods_evaluated_expression.)
	%local /readonly _TMP_DS_EVALUATED_EXPR = %&RSUDS.GetTempDSName(evaluated_expr);
	%local _group_index;
	%do _group_index = 0 %to &i_max_group.;
		data _null_;
			_dsid = open("&ids_expressions.(where = (&i_variable_name_group. = &_group_index.))", 'I');
			call execute("data &_TMP_DS_EVALUATED_EXPR.(keep = &i_variable_name_expr_id. &i_variable_name_value.); attrib &i_variable_name_value. length = $100.;");
			_rc = fetch(_dsid);
			do while(_rc = 0);
				call execute(cats("&i_variable_name_expr_id. = ", getvarn(_dsid, 2), "; &i_variable_name_value. = compress(put(", getvarc(_dsid, 1), ', BEST.)); output;'));
				_rc = fetch(_dsid);
			end;
			_rc = close(_dsid);
			call execute('run; quit;');
		run;
		quit;
		%&RSUDS.Append(iods_base_ds = &ods_evaluated_expression.
							, ids_data_ds = &_TMP_DS_EVALUATED_EXPR.)
		%&RSUDS.Delete(&_TMP_DS_EVALUATED_EXPR.)
	%end;
%mend EvaluateExpressionHelper;

/**====================================================================*/
/* 式評価
/*
/* NOTE: 通常バージョン（中速 ネットから拝借）
/* NOTE: https://blogs.sas.com/content/sgf/2021/06/25/how-to-evaluate-sas-expression-in-data-step-dynamically/#comments
/**====================================================================*/
%macro ExprEvl__EvaluateExpression_Mid(ids_evaluable_expression =
													, i_evaluated_expression_variable =
													, ods_evaluation_result =);
	%&RSUDS.Protect(&ids_evaluable_expression.)
	data _null_;
		set &ids_evaluable_expression. end = eof;
		if (_N_ = 1) then do;
			call execute("data &ods_evaluation_result.(drop = _value &i_evaluated_expression_variable.); set &ids_evaluable_expression.; attrib _value length = 8. value length = $100.;");
		end;
		call execute(cats('if(_N_ = ', _N_, ') then do; _value = ', &i_evaluated_expression_variable., '; value = compress(put(_value, BEST.)); end;'));
		if (eof) then do;
			call execute('run; quit;');
		end;
	run;
	quit;
	%&RSUDS.Unprotect(&ids_evaluable_expression.)
%mend ExprEvl__EvaluateExpression_Mid;

/**====================================================================*/
/* 式評価
/*
/* NOTE: 分析バージョン（低速、しかし、エラーで止まらない）
/**====================================================================*/
%macro ExprEvl__EvaluateExprDiag(ids_evaluable_expression =
											, i_evaluated_expression_variable =
											, ods_evaluation_result =);
	%&RSUDS.Protect(&ids_evaluable_expression.)
	%local _value;
	data &ods_evaluation_result.(drop = _:);
		set &ids_evaluable_expression.;
		attrib
			value length = $100.
		;
		call symputx('_value', 'NaN');
		_rc = dosubl(cats('data _null; _value = (', &i_evaluated_expression_variable., '); call symputx("_value", _value); run; quit;'));
		value = compress(symget('_value'));
	run;
	quit;
	%&RSUDS.Unprotect(&ids_evaluable_expression.)
%mend ExprEvl__EvaluateExprDiag;

/**===============================================**/
/* 代入
/**===============================================**/
%macro ExprEvl__SubstituteValues(iods_expressions =
											, i_variable_expression_index =
											, i_variable_expression =
											, i_regex =
											, i_no_of_functions =
											, ids_value =
											, i_variable_key =
											, i_variable_value =
											, ids_time_axis =
											, i_variable_time_index =
											, i_variable_time =
											, ods_evaluable_exressions =);
	%local /readonly _IS_ARGUMENT_USED = %&RSUUtil.Choose(%&RSUUtil.IsMacroBlank(ids_time_axis), %&RSUBool.False, %&RSUBool.True);
	data
		&ods_evaluable_exressions.(keep = &i_variable_expression_index. &i_variable_expression.)
		&iods_expressions.
		;
		if (_N_ = 0) then do;
			set 
				&ids_value.
	%if (&_IS_ARGUMENT_USED.) %then %do;
				&ids_time_axis.
	%end;
			;
		end;
		set &iods_expressions.(keep = address addr__: &i_variable_expression. &i_variable_expression_index. &G_CONST_VAR_VARIABLE_REF_NAME. &i_variable_time_index. &i_variable_time.) end = eof;
		attrib
			__tmp_decmp_expression_replaced length = $3000.
			__tmp_decmp_definition length = $3000.
			__tmp_decmp_term length = $200.
			__tmp_decmp_function length = $20.
			__tmp_decmp_function_supl length = $20.
			__tmp_decmp_layer_li_key length = $100.
			__tmp_decmp_time_indicator_abs length = $10.
			__tmp_decmp_time_indicator_rel length = $10.
			__tmp_decmp_layer_key_time length = $8.
			__tmp_decmp_original length = $200.
		;
		if (_N_ = 1) then do;
			declare hash hh_value(dataset: "&ids_value.");
			__rc = hh_value.definekey("&i_variable_key.");
			__rc = hh_value.definedata("&i_variable_value.");
			__rc = hh_value.definedone();
			
	%if (&_IS_ARGUMENT_USED.) %then %do;
			declare hash hh_time(dataset: "&ids_time_axis.");
			__rc = hh_time.definekey("time_axis_&i_variable_time_index.");
			__rc = hh_time.definedata("time_axis_&i_variable_time.");
			__rc = hh_time.definedone();
	%end;
		end;
		__tmp_decmp_regex_formula_ref = prxparse("/&i_regex./o");
		__tmp_decmp_definition = cat('`', strip(&i_variable_expression.), '`');
		__tmp_decmp_org_length = lengthn(__tmp_decmp_definition);
		__tmp_decmp_start = 1;
		__tmp_decmp_stop = __tmp_decmp_org_length;
		__tmp_decmp_position = 0;
		__tmp_decmp_length = 0;
		__tmp_decmp_prev_start = 1;
		__tmp_decmp_finished = 0;
		__tmp_decmp_safty_index = 0;
		__tmp_decmp_expression_replaced = '';
		do while(__tmp_decmp_safty_index < 100);
			call prxnext(__tmp_decmp_regex_formula_ref, __tmp_decmp_start, __tmp_decmp_stop, __tmp_decmp_definition, __tmp_decmp_position, __tmp_decmp_length);
			if (__tmp_decmp_position = 0) then do;
				__tmp_decmp_finished = 1;
				__tmp_decmp_position = __tmp_decmp_org_length; 
			end;
			__tmp_decmp_expression_replaced = catt(__tmp_decmp_expression_replaced, cat('`', substr(__tmp_decmp_definition, __tmp_decmp_prev_start, __tmp_decmp_position - __tmp_decmp_prev_start + 1), '`'));
			if (__tmp_decmp_finished = 1) then do;
				leave;
			end;
			__tmp_decmp_original = substr(__tmp_decmp_definition, __tmp_decmp_position + 1, __tmp_decmp_length - 1);
			__tmp_decmp_function = prxposn(__tmp_decmp_regex_formula_ref, 1, __tmp_decmp_definition);
			__tmp_decmp_function_supl = prxposn(__tmp_decmp_regex_formula_ref, &i_no_of_functions. + 3, __tmp_decmp_definition);
			__tmp_decmp_term = catt(__tmp_decmp_function, prxposn(__tmp_decmp_regex_formula_ref, &i_no_of_functions. + 2, __tmp_decmp_definition), '{', prxposn(__tmp_decmp_regex_formula_ref, &i_no_of_functions. + 4, __tmp_decmp_definition), '}');
			__tmp_decmp_function = coalescec(__tmp_decmp_function_supl, __tmp_decmp_function);
			&i_variable_key. = __tmp_decmp_term;
	%if (&_IS_ARGUMENT_USED.) %then %do;
			__tmp_decmp_time_indicator_abs = prxposn(__tmp_decmp_regex_formula_ref, &i_no_of_functions. + 7, __tmp_decmp_definition);
			__tmp_decmp_time_indicator_rel = prxposn(__tmp_decmp_regex_formula_ref, &i_no_of_functions. + 8, __tmp_decmp_definition);
			if (not missing(__tmp_decmp_time_indicator_abs)) then do;
				__tmp_decmp_layer_key_time = __tmp_decmp_time_indicator_abs;
			end;
			else if (not missing(__tmp_decmp_time_indicator_rel)) then do;
				time_axis_&i_variable_time_index. = &i_variable_time_index. + input(__tmp_decmp_time_indicator_rel, best.);
				__rc = hh_time.find();
				__tmp_decmp_layer_key_time = compress(put(time_axis_&i_variable_time., BEST.));
			end;
			else do;
				__tmp_decmp_layer_key_time = compress(put(&i_variable_time., BEST.));
			end;
			__tmp_decmp_layer_li_key = vvaluex(catt('addr__', __tmp_decmp_function));
			__tmp_decmp_layer_li_key = tranwrd(__tmp_decmp_layer_li_key, '@', __tmp_decmp_layer_key_time);
			&i_variable_key. = catx(';', __tmp_decmp_layer_li_key, __tmp_decmp_term);
	%end;
			&i_variable_key. = compress(&i_variable_key.);
			&i_variable_key. = tranwrd(&i_variable_key., '[(', '[');
			&i_variable_key. = tranwrd(&i_variable_key., ')]', ']');
			__rc = hh_value.find();
			if (__rc = 0) then do;
				__tmp_decmp_expression_replaced = catt(__tmp_decmp_expression_replaced, catt('(', value, ')'));			
			end;
			else do;
				__tmp_decmp_expression_replaced = catt(__tmp_decmp_expression_replaced, __tmp_decmp_original);			
			end;
			__tmp_decmp_time_indicator_abs = '';
			__tmp_decmp_time_indicator_rel = '';
			__tmp_decmp_prev_start = __tmp_decmp_position + __tmp_decmp_length;
			__tmp_decmp_safty_index = __tmp_decmp_safty_index + 1;
		end;
		&i_variable_expression. = compress(__tmp_decmp_expression_replaced, '`');
		if (find(&i_variable_expression. , '{')) then do;
			output &iods_expressions;
		end;
		else do;
			output &ods_evaluable_exressions.;
		end;
		drop
			__rc
			__tmp_decmp_:
			&i_variable_key.
			&i_variable_value.
		;
	run;
	quit;
%mend ExprEvl__SubstituteValues;
