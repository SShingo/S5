/******************************************************/
/* FormulaEvaluator.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/******************************************************/
%RSUSetConstant(FormulaEvaluator, FormEvl__)

/**===============================================**/
/* Formula 評価
/*
/* NOTE: 使用Formula フィルタリング: formula_appl_conditionをVPR展開→値入力データを代入→評価→選択
/* NOTE: ヒストリカル評価: variable_ref_name + レイヤーで値入力データを代入→評価されたものを結果として保存
/* NOTE: 静的数値代入: formula_definition_rhsをVPR展開→値入力データを代入
/* NOTE: 評価ループ: fragment_unevaluated（すべてはRef{****}になっている）を評価
/* NOTE: 結果保存
/**===============================================**/
%macro FormEvl__Evaluate(i_formula_set_id =
								, iods_formula_address =
								, ids_value_pool =
								, i_regex_formula_parsing =
								, i_no_of_input_data =
								, i_regex_parameter_table =); 
	%&RSULogger.PutSubsection(Evaluating formula "&i_formula_set_id."...)
	/* Extend */
	%local /readonly _TMP_DS_FITERING_FORMULA = %&RSUDS.GetTempDSName(filtering_formula);
	%&RSUDS.Let(i_query = &G_CONST_DS_FORMULA_DEFINITION.(where = (formula_set_id = "&i_formula_set_id."));
					, ods_dest_ds = &_TMP_DS_FITERING_FORMULA.(keep = formula_system_id___ formula_appl_condition formula_definition_rhs formula_order &G_CONST_VAR_VARIABLE_REF_NAME.))
	%local /readonly _TMP_DS_EXTENDED_FORMULA_DEF = %&RSUDS.GetTempDSName(extended_formula);
	%&FormulaParser.ExtendFormula(iods_formula_address = &iods_formula_address.
											, ids_formula_ds = &_TMP_DS_FITERING_FORMULA.)
	%&RSUDS.Delete(&_TMP_DS_FITERING_FORMULA.)
	/* Filtering */
	%FilterFormula(i_formula_set_id = &i_formula_set_id.
						, iods_extended_formula = &iods_formula_address.
						, ids_value_pool = &ids_value_pool.
						, i_regex_formula_parsing = &_regex_formula_parsing.
						, i_no_of_input_data = &_no_of_input_data.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to filter input data.)
		%return;
	%end;
	%local /readonly _TMP_DS_PREV_ADDRESS = %&RSUDS.GetTempDSName(prev_address);
	%&RSUDS.Let(i_query = &iods_formula_address.(keep = address formula_index addr__&i_formula_set_id. &G_CONST_VAR_VARIABLE_REF_NAME.)
					, ods_dest_ds = &_TMP_DS_PREV_address.)
	/* 右辺に代入 */
	%local /readonly _TMP_DS_EVALUATED_VALUES = %&RSUDS.GetTempDSName(evaluated_value);
	%local /readonly _TMP_DS_NEXT_INPUT_DATA = %&RSUDS.GetTempDSName(next_input_data);
	%ComputeInitialState(i_formula_set_id = &i_formula_set_id.
								, iods_extended_formula = &iods_formula_address.
								, ids_value_pool = &ids_value_pool.
								, i_regex_formula_parsing = &_regex_formula_parsing.
								, i_no_of_input_data = &_no_of_input_data.
								, i_regex_parameter_table = &_regex_parameter_table.
								, ods_result = &_TMP_DS_EVALUATED_VALUES.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to prepare input data.)
		%return;
	%end;
	%&ValuePool.CreateInputData(i_formula_set_id = &i_formula_set_id.
										, ids_result = &_TMP_DS_EVALUATED_VALUES.
										, ids_formula_address = &_TMP_DS_PREV_address.
										, ods_next_input_data = &_TMP_DS_NEXT_INPUT_DATA)
	%&RSUDS.Delete(&_TMP_DS_EVALUATED_VALUES. &_TMP_DS_PREV_ADDRESS.)
	%local /readonly _NO_OF_REMAINING_FORMULA = %&RSUDS.GetCount(&iods_formula_address.);
	%if (&_NO_OF_REMAINING_FORMULA. = 0) %then %do;
		%&RSULogger.PutInfo(All formulas evaluated)
		%&RSULogger.PutSubsection(Finish evaluation)
		%goto __skip_iteration__;
	%end;
	%else %do;
		%&RSULogger.PutInfo(&_NO_OF_REMAINING_FORMULA. formulas still unevaluated.)
	%end;
	/* ループ */
	%StartIteration(i_formula_set_id = &i_formula_set_id.
						, iods_extended_formula = &iods_formula_address.
						, ids_input_data = &_TMP_DS_NEXT_INPUT_DATA.)
	%&RSUDS.Delete(&_TMP_DS_NEXT_INPUT_DATA.)
%__skip_iteration__:
%mend FormEvl__Evaluate;

/*-----------------------------------------------*/
/* Formula フィルタリング
/*
/* NOTE: formula_appl_conditionを評価
/* NOTE: 生き残ったLayer elementがFormula評価に渡される
/*-----------------------------------------------*/
%macro FilterFormula(i_formula_set_id =
							, iods_extended_formula =
							, ids_value_pool =
							, i_regex_formula_parsing =
							, i_no_of_input_data =);
	%&RSULogger.PutNote(Filtering formula difinition by evaluating formula_appl_condition in "&i_formula_set_id."...)
	/* 無条件Formula と条件付きFormula に分割 */
	%local /readonly _TMP_DS_FORMULA_CONDITIONED = %&RSUDS.GetTempDSName(formula_conditioned);
	data
			&_TMP_DS_FORMULA_CONDITIONED.
			&iods_extended_formula.(drop = formula_appl_condition)
		;
		set &iods_extended_formula.;
		if (compress(formula_appl_condition) = '1') then do;
			output &iods_extended_formula.;
		end;
		else do;
			output &_TMP_DS_FORMULA_CONDITIONED.;
		end;
	run;
	quit;
	%&RSULogger.PutInfo(Formula definition has been splitted into two part.)
	%&RSULogger.PutBlock(# of conditioned formula: %&RSUDS.GetCount(&_TMP_DS_FORMULA_CONDITIONED.)
								, # of unconditined formula: %&RSUDS.GetCount(&iods_extended_formula.))
	%if (not %&RSUDS.IsDSEmpty(&_TMP_DS_FORMULA_CONDITIONED.)) %then %do;
		%FilterFormulaHelper(iods_conditioned_formulas = &_TMP_DS_FORMULA_CONDITIONED.
									, ids_value_pool = &ids_value_pool.
									, ids_regex_vpr_function = &i_regex_formula_parsing.
									, i_no_of_vpr_functions = &i_no_of_input_data.)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Stop()
			%return;
		%end;
		%&RSUDS.Append(iods_base_ds = &iods_extended_formula.
							, ids_data_ds = &&_TMP_DS_FORMULA_CONDITIONED.)						
	%end;
	%else %do;
		%&RSULogger.PutInfo(No conditioned formula found.)
	%end;
	%&RSUDS.Delete(&_TMP_DS_FORMULA_CONDITIONED.)
	%PickupAppliedFormula(iods_formula_definition = &iods_extended_formula.)
%mend FilterFormula;

/*-----------------------------------------------*/
/* Formula のフィルタリングヘルパー
/*
/* NOTE: formula_appl_conditionを評価
/* NOTE: 各variable_ref_name毎に最初に formula_appl_condition = 1と評価されたものを採用する
/* NOTE: （チューニング）formula_appl_condition = null を許可（無条件採用）
/* NOTE: 高速VPRパーサーを利用
/*-----------------------------------------------*/
%macro FilterFormulaHelper(iods_conditioned_formulas =
									, ids_value_pool =
									, ids_regex_vpr_function =
									, i_no_of_vpr_functions =);
	%&RSULogger.PutInfo(%&RSUDS.GetCount(&iods_conditioned_formulas.) formulas will be filtered.)
	%local /readonly _TMP_DS_COND_EVALUATED_FORM = %&RSUDS.GetTempDSName(cond_evaluated_form);
	%&RSUDS.Let(i_query = &iods_conditioned_formulas.
					, ods_dest_ds = &_TMP_DS_COND_EVALUATED_FORM.)
	%&ExpressionEvaluator.SubstituteValues(iods_expressions = &iods_conditioned_formulas.
														, i_variable_expression_index = formula_index
														, i_variable_expression = formula_appl_condition
														, i_regex = &i_regex_formula_parsing.
														, i_no_of_functions = &i_no_of_input_data.
														, ids_value = &ids_value_pool.
														, i_variable_key = value_key
														, i_variable_value = value
														, ids_time_axis = &G_CONST_DS_TIME_AXIS.
														, i_variable_time_index = horizon_index
														, i_variable_time = &G_CONST_VAR_TIME.
														, ods_evaluable_exressions = WORK.evaluables)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to evaluate formula_appl_condition.)
		%return;
	%end;
	%if (not %&RSUDS.IsDSEmpty(WORK.evaluables)) %then %do;
		%&ExpressionEvaluator.EvaluateExpression(ids_expressions = WORK.evaluables
															, i_variable_name_expr_id = formula_index
															, i_variable_target_expr = formula_appl_condition
															, i_variable_name_value = value
															, ods_evaluated_expression = WORK.evaluated)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to evaluate formula)
			%return;
		%end;
	%end;

	%let _no_of_ignored = %&RSUDS.GetCount(&iods_conditioned_formulas.);
	%local _discard;
	%local _applied;
	data &&iods_conditioned_formulas.(drop = _rc value formula_appl_condition _no_of:);
		if (_N_ = 0) then do;
			set WORK.evaluated;
		end;
		set &_TMP_DS_COND_EVALUATED_FORM. end = eof;
		retain _no_of_applied 0;
		retain _no_of_discared 0;
		if (_N_ = 1) then do;
			declare hash hh_filter(dataset: "WORK.evaluated");
			_rc = hh_filter.definekey('formula_index');
			_rc = hh_filter.definedata('value');
			_rc = hh_filter.definedone();
		end;
		_rc = hh_filter.find();
		if (_rc = 0) then do;
			if (value = '1') then do;
				_no_of_applied = _no_of_applied + 1;
				output;
			end;
			else do;
				_no_of_discared = _no_of_discared + 1;
			end;
		end;
		if (eof) then do;
			call symputx('_discard', _no_of_discared);
			call symputx('_applied', _no_of_applied);
		end;
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_COND_EVALUATED_FORM.)
	%&RSULogger.PutBlock([Filter result]
								, # of applied formula: &_applied.
								, # of discarded formula: %eval(&_no_of_ignored. + &_discard.)  (violate: &_discard. ignored &_no_of_ignored.))
%mend FilterFormulaHelper;

/*-----------------------------------------------------*/
/* 採用条件を評価し、採用 formulaを決定
/* 同一 layer element, 同一 formula_def_idの内部を formula_order順に評価し、最初にtrueのものを採用
/*-----------------------------------------------------*/
%macro PickupAppliedFormula(iods_formula_definition =);
	%&RSULogger.PutNote(Picking up applied formula for each variable from %&RSUDS.GetCount(&iods_formula_definition.) formulas)
	proc sort data = &iods_formula_definition.;
		by
			address
			&G_CONST_VAR_VARIABLE_REF_NAME.
			formula_order
		;
	run;
	quit;
	%local _no_of_pickuped_formula;
	data &iods_formula_definition.(drop = _no_of_pickuped_definition formula_order);
		set &iods_formula_definition. end = eof;
		by
			address
			&G_CONST_VAR_VARIABLE_REF_NAME.
			formula_order
		;
		retain _no_of_pickuped_definition 0;
		if (first.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			_no_of_pickuped_definition = _no_of_pickuped_definition + 1;
			output;
		end;
		if (eof) then do;
			call symputx('_no_of_pickuped_formula', _no_of_pickuped_definition);
		end;
	run;
	quit;
	%&RSULogger.PutInfo(# of pickuped formulas: &_no_of_pickuped_formula.)
%mend PickupAppliedFormula;

/*----------------------------*/
/* 初期状態構築
/*----------------------------*/
%macro ComputeInitialState(i_formula_set_id =
									, iods_extended_formula =
									, ids_value_pool =
									, i_regex_formula_parsing =
									, i_no_of_input_data =
									, i_regex_parameter_table =
									, ods_result =);
	%&RSULogger.PutParagraph(Substituting input data into rhs of formula definition.)
	%&RSUDS.Delete(&ods_result.)
	%&ExpressionEvaluator.SubstituteValues(iods_expressions = &iods_extended_formula.
														, i_variable_expression_index = formula_index
														, i_variable_expression = formula_definition_rhs
														, i_regex = &i_regex_formula_parsing.
														, i_no_of_functions = &i_no_of_input_data.
														, ids_value = &ids_value_pool.
														, i_variable_key = value_key
														, i_variable_value = value
														, ids_time_axis = &G_CONST_DS_TIME_AXIS.
														, i_variable_time_index = horizon_index
														, i_variable_time = &G_CONST_VAR_TIME.
														, ods_evaluable_exressions = WORK.evaluables)
	%if (not %&RSUDS.IsDSEmpty(WORK.evaluables)) %then %do;
		%&ExpressionEvaluator.EvaluateExpression(ids_expressions = WORK.evaluables
															, i_variable_name_expr_id = formula_index
															, i_variable_target_expr = formula_definition_rhs
															, i_variable_name_value = value
															, ods_evaluated_expression = WORK.evaluated)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to evaluate formula)
			%return;
		%end;
		%&RSUDS.Concat(iods_base_ds = &ods_result.
							, ids_data_ds = WORK.evaluated)
		%&RSUDS.Delete(WORK.evaluated)
	%end;

	%&ExpressionEvaluator.SubstituteValues(iods_expressions = &iods_extended_formula.
														, i_variable_expression_index = formula_index
														, i_variable_expression = formula_definition_rhs
														, i_regex = &i_regex_parameter_table.
														, i_no_of_functions = 1
														, ids_value = &G_CONST_DS_PARAMETER_TABLE.
														, i_variable_key = value_key
														, i_variable_value = value
														, i_variable_time_index = horizon_index
														, i_variable_time = &G_CONST_VAR_TIME.
														, ods_evaluable_exressions = WORK.evaluables)
	%if (not %&RSUDS.IsDSEmpty(WORK.evaluables)) %then %do;
		%&ExpressionEvaluator.EvaluateExpression(ids_expressions = WORK.evaluables
															, i_variable_name_expr_id = formula_index
															, i_variable_target_expr = formula_definition_rhs
															, i_variable_name_value = value
															, ods_evaluated_expression = WORK.evaluated)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to evaluate formula)
			%return;
		%end;
		%&RSUDS.Concat(iods_base_ds = &ods_result.
							, ids_data_ds = WORK.evaluated)
		%&RSUDS.Delete(WORK.evaluated)
	%end;
	%&RSUDS.Delete(WORK.evaluables)

	%&RSULogger.PutInfo(%&RSUDS.GetCount(&ods_result.) formulas evaluated initilally)
%mend ComputeInitialState;

/*----------------------------*/
/* 評価ループ
/*----------------------------*/
%macro StartIteration(i_formula_set_id =
							, iods_extended_formula =
							, ids_input_data =);
	%&RSULogger.PutSubsection(Start evaluation iteration)
	%local /readonly _DECOMP_REGEX_REF = %&VPRParser.CreateDecompRegex(i_functions = &G_CONST_VPR_FUNC_REF.
																							, i_regex_delimiter = &G_CONST_REGEX_VPR_FUNC_DELM.
																							, i_regex_argument = &G_CONST_REGEX_VPR_FUNC_ARGUMENT.);
	%local /readonly _TMP_DS_PREV_address_ITE = %&RSUDS.GetTempDSName(prev_address);
	%local _no_of_remaining_expressions;
	%let _no_of_remaining_expressions = %&RSUDS.GetCount(&iods_extended_formula.);
	%local _no_of_newly_evaluated_formula;
	%local _interation;
	%&RSUDS.Let(i_query = &ids_input_data.
					, ods_dest_ds = WORK.evaluated)
	%do _interation = 1 %to &G_SETTING_MAX_EVALUATION_ITER.;
		%&RSULogger.PutInfo(Start #&&_interation. iteration(# of remaining formulas: &_no_of_remaining_expressions.))
		%&RSUDS.Let(i_query = &iods_extended_formula.(keep = formula_index address addr__&i_formula_set_id. &G_CONST_VAR_VARIABLE_REF_NAME.)
						, ods_dest_ds = &_TMP_DS_PREV_address_ITE.)
		%&ExpressionEvaluator.SubstituteValues(iods_expressions = &iods_extended_formula.
															, i_variable_expression_index = formula_index
															, i_variable_expression = formula_definition_rhs
															, i_regex = &_DECOMP_REGEX_REF.
															, i_no_of_functions = 1
															, ids_value = WORK.evaluated
															, i_variable_key = value_key
															, i_variable_value = value
															, ids_time_axis = &G_CONST_DS_TIME_AXIS.
															, i_variable_time_index = horizon_index
															, i_variable_time = _time_
															, ods_evaluable_exressions = WORK.evaluables)
		%let _no_of_newly_evaluated_formula = %&RSUDS.GetCount(WORK.evaluables);
		%if (&_no_of_newly_evaluated_formula. = 0) %then %do;
			%&RSULogger.PutError(Failed to evaluate formulas @ iteration &&_interation.)
			%&RSULogger.PutError(&_no_of_remaining_expressions. formulas cannot be evaluated.)
			%&RSULogger.PutError(Unevaluated formulas saved as L_WORK.Error_&i_formula_set_id.)
			%&RSUDS.Move(i_query = &iods_extended_formula.
							, ods_dest_ds = L_WORK.Error_&i_formula_set_id.)
			%&RSUError.Throw(Failed to evaluate formulas)
			%return;
		%end;
		%&ExpressionEvaluator.EvaluateExpression(ids_expressions = WORK.evaluables
															, i_variable_name_expr_id = formula_index
															, i_variable_target_expr = formula_definition_rhs
															, i_variable_name_value = value
															, ods_evaluated_expression = WORK.evaluated)
		%&RSULogger.PutInfo(&_no_of_newly_evaluated_formula. formulas evaluated newly)
		%&RSUDS.Delete(WORK.evaluables)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to evaluate formula)
			%return;
		%end;
		%&ValuePool.CreateInputData(i_formula_set_id = &i_formula_set_id.
											, ids_result = WORK.evaluated
											, ids_formula_address = &_TMP_DS_PREV_address_ITE.
											, ods_next_input_data = WORK.evaluated)
		%&RSUDS.Delete(&_TMP_DS_PREV_address_ITE.)
		%let _no_of_remaining_expressions = %&RSUDS.GetCount(&iods_extended_formula.);
		%if (&_no_of_remaining_expressions. = 0) %then %do;
			%&RSULogger.PutSubsection(Finish evaluation)
			%&RSUDS.Delete(WORK.evaluated)
			%return;
		%end;
		%&RSULogger.PutInfo(End #&&_interation.)
	%end;
%mend StartIteration;
