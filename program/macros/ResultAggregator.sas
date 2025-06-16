/***************************************************/
/*	ResultAggregator.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/***************************************************/
%RSUSetConstant(ResultAggregator, RsltAggr__)

/**=================================**/
/* 結果 Value Pool の集約
/*
/* NOTE: レイヤーIDで集約
/**=================================**/
%macro RsltAggr__AggregateResult(i_formula_set_id =
											, ids_formula_result =
											, ods_aggregated_result =);
	%&RSULogger.PutSubsection(Aggregating result of formula "&i_formula_set_id.")
	%if (%&RSUDS.IsDSEmpty(&G_SETTING_CONFIG_DS_RESULT_AGGR.(where = (formula_set_id = "&i_formula_set_id.")))) %then %do;
		%&RSULogger.PutInfo(No aggregation tasks follows formula evaluation of "&i_formula_set_id.".)
		%return;
	%end;

	%local /readonly _TMP_DS_SOURCE = %&RSUDS.GetTempDSName(source_ds);
	data &_TMP_DS_SOURCE.;
		set &ids_formula_result.;
		attrib
			&G_CONST_VAR_VARIABLE_REF_NAME. length = $100.
		;
		&G_CONST_VAR_VARIABLE_REF_NAME. = scan(value_key, -1, ';');
		_value = input(value, BEST.);
	run;
	quit;
	%local /readonly _NO_OF_OBSERVATION_BEFORE = %&RSUDS.GetCount(&_TMP_DS_SOURCE.);
	%&RSUDS.GetUniqueList(i_query = &G_SETTING_CONFIG_DS_RESULT_AGGR.(where = (formula_set_id = "&i_formula_set_id."))
								, i_by_variables = data_id_output
								, ods_output_ds = WORK.tmp_data_list(keep = data_id_output))
	%local _data_id_output;
	%local _dsid_data_id_output;
	%local _aggregation_target;
	%local _aggregation_method;
	%local _aggregation_layer;
	%local _dsid_aggr;
	%local _aggregation_by_layer;
	%local _no_of_observation_after;
	%local _layer_variable_time;
	%local _layer_variable_scenario;
	%local /readonly _TMP_DS_AGGREGATION = %&RSUDS.GetTempDSName(aggregation);
	%&RSUDS.Delete(&_TMP_DS_AGGREGATION.)
	%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_data_list
										, i_vars = _data_id_output:data_id_output
										, ovar_dsid = _dsid_data_id_output));
		%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_RESULT_AGGR.(where = (formula_set_id = "&i_formula_set_id." and data_id_output = "&_data_id_output."))
											, i_vars = _aggregation_target:aggregation_target 
														_aggregation_method:aggregation_method 
														_aggregation_layer:aggregation_layer
											, ovar_dsid = _dsid_aggr));
			%let _layer_variable_time = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&_data_id_output."))
																	, i_variable = &G_CONST_VAR_ROLE_TIME.);
			%let _layer_variable_scenario = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&_data_id_output."))
																			, i_variable = &G_CONST_VAR_ROLE_SCENARIO.);
			%&RSULogger.PutParagraph(Aggregating formula result "%&DataObject.DSVariablePart(i_suffix = &i_formula_set_id.)")
			%&RSULogger.PutBlock(Target variable: &_aggregation_target.
										, Aggregation method: &_aggregation_method.
										, Aggregation layer: &_aggregation_layer. &_layer_variable_time. &_layer_variable_scenario.)
			/*
				Sum, Prod, Avg, Min, Max Count
				! 集計関数別に書くしかないか
			*/
			%SortResultDSForAggregation(ids_source_ds = &_TMP_DS_SOURCE.
												, i_formula_set_id = &i_formula_set_id.
												, i_aggregation_target = &_aggregation_target.
												, i_by_layer_variables = &_aggregation_layer. &_layer_variable_time. &_layer_variable_scenario.
												, ods_sorted = WORK.tmp_aggregation_sorted)
			%Aggregate_&_aggregation_method.(ids_input_ds = WORK.tmp_aggregation_sorted
														, ods_output_ds = WORK.tmp_aggregation_result
														, i_by_layers = &_aggregation_layer. &_layer_variable_time. &_layer_variable_scenario.)
			%PostProcessOfAggregation(iods_aggregated_ds = WORK.tmp_aggregation_result
											, i_aggregation_method = &_aggregation_method.
											, i_by_layer_variables = &_aggregation_layer. &_layer_variable_time. &_layer_variable_scenario.)
			%let _no_of_observation_after = %&RSUDS.GetCount(WORK.tmp_aggregation_result);
			%&RSULogger.PutInfo(# of records changed from &_NO_OF_OBSERVATION_BEFORE. to &_no_of_observation_after.)

			%&RSUDS.Append(iods_base_ds = &_TMP_DS_AGGREGATION.
								, ids_data_ds = WORK.tmp_aggregation_result)
			%&RSUDS.Delete(WORK.tmp_aggregation_result WORK.tmp_aggregation_sorted)
		%end;
		%GenerateLayer(i_data_id = &_data_id_output.
							, ids_result = &_TMP_DS_AGGREGATION.
							, ids_variable_layers = &_aggregation_layer.
							, i_layer_type = &G_CONST_VAR_ROLE_SPACE.
							, i_address_pos = 1)
		%GenerateLayer(i_data_id = &_data_id_output.
							, ids_result = &_TMP_DS_AGGREGATION.
							, ids_variable_layers = &_layer_variable_scenario.
							, i_layer_type = &G_CONST_VAR_ROLE_SCENARIO.
							, i_address_pos = 2)
		data %&LayerManager.DSDataLayer(i_data_id = &_data_id_output., i_layer_type = &G_CONST_VAR_ROLE_TIME.);
			set &_TMP_DS_AGGREGATION.(keep = &G_CONST_VAR_TIME horizon_index);
		run;
		quit;
		proc sort data = %&LayerManager.DSDataLayer(i_data_id = &_data_id_output., i_layer_type = &G_CONST_VAR_ROLE_TIME.) nodupkey;
			by
				&G_CONST_VAR_TIME.
				horizon_index
			;
		run;
		quit;
		data %&LayerManager.DSDataLayer(i_data_id = &_data_id_output., i_layer_type = &G_CONST_VAR_ROLE_TIME.);
			set %&LayerManager.DSDataLayer(i_data_id = &_data_id_output., i_layer_type = &G_CONST_VAR_ROLE_TIME.);
			coordinate = _N_;
		run;
		quit;
		%&RSUDS.Delete(&_TMP_DS_SOURCE.)
		%&RSUDS.Let(i_query = &_TMP_DS_AGGREGATION.
						, ods_dest_ds = &ods_aggregated_result.)
		%&RSUDS.Move(i_query = &_TMP_DS_AGGREGATION.(keep = value value_key)
						, ods_dest_ds = %&DataObject.DSVariablePart(i_suffix = &_data_id_output.))
	%end;
	%&RSUDS.Delete(WORK.tmp_data_list)
%mend RsltAggr__AggregateResult;

%macro SortResultDSForAggregation(ids_source_ds =
											, i_formula_set_id =
											, i_aggregation_target =
											, i_by_layer_variables =
											, ods_sorted =);
	proc sort data = &ids_source_ds.(where = (&G_CONST_VAR_VARIABLE_REF_NAME. = "&G_CONST_VPR_FUNC_REF.[&i_formula_set_id.]{&i_formula_set_id.!&_aggregation_target.}")) out = &ods_sorted.;
		by
			&i_by_layer_variables.
			&G_CONST_VAR_VARIABLE_REF_NAME.
		;
	run;
	quit;
%mend SortResultDSForAggregation;

%macro PostProcessOfAggregation(i_formula_set_id =
										, iods_aggregated_ds =
										, i_aggregation_method =
										, i_by_layer_variables =);
	data &iods_aggregated_ds.(drop = agg);
		set &iods_aggregated_ds.;
		value_key = prxchange("s/^([\d|\.]+;[\d|\.]+;[\d|\.]+;&G_CONST_VPR_FUNC_REF.\[\w+\]\{)([^\}]+\})$/$1&i_aggregation_method.Of:$2/", -1, trim(value_key));
		&G_CONST_VAR_VALUE. = compress(put(agg, BEST.));
	run;
	quit;
%mend PostProcessOfAggregation;

%macro GenerateLayer(i_data_id =
							, ids_result = 
							, ids_variable_layers =
							, i_layer_type =
							, i_address_pos =);
	%if (%&RSUUtil.IsMacroBlank(ids_variable_layers)) %then %do;
		%&RSULogger.PutInfo(No &i_layer_type. layer in aggregation result)
		%return;
	%end;

	data WORK.tmp_aggr_layer(drop = value_key);
		set &ids_result.(keep = &ids_variable_layers. value_key);
		coordinate = input(scan(value_key, &i_address_pos., ';'), BEST.);
	run;
	quit;

	proc sort data = WORK.tmp_aggr_layer nodupkey;
		by
			coordinate
		;
	run;
	data %&LayerManager.DSDataLayer(i_data_id = &i_data_id., i_layer_type = &i_layer_type.);
		set WORK.tmp_aggr_layer;
	run;
	%&RSUDS.Delete(WORK.tmp_aggr_layer)
%mend GenerateLayer;

%macro EncodeLayerInAggrHelper(i_layer_componens =
										, ids_layer =
										, i_target_layer =
										, iods_result_aggr =);
	%local _layer_component;
	%local _index_layer_component;
	data &iods_result_aggr.(drop = &i_layer_componens. __rc);
		if (_N_ = 0) then do;
			set &ids_layer.;
		end;
		set &iods_result_aggr.;
		if (_N_ = 1) then do;
			declare hash hh_layer(dataset: "&ids_layer.");
	%do %while(%&RSUUtil.ForEach(i_items = &i_layer_componens.
										, ovar_item = _layer_component
										, iovar_index = _index_layer_component));
			__rc = hh_layer.definekey("&_layer_component.");
	%end;
			__rc = hh_layer.definedata("&i_target_layer.");
			__rc = hh_layer.definedone();
		end;
		__rc = hh_layer.find();
		if (__rc = 0) then do;
			output;
		end;
	run;
	quit;
%mend EncodeLayerInAggrHelper;

/*******************************************/
/* 以下: 各種集計関数
/*******************************************/
%macro Aggregate_Sum(ids_input_ds =
							, ods_output_ds =
							, i_by_layers =);
	%&RSUDS.Protect(&ids_input_ds.)
	data &ods_output_ds.;
		set &ids_input_ds.;
		by
			&i_by_layers.
			&G_CONST_VAR_VARIABLE_REF_NAME.
		;
		retain agg 0;
		if (first.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			agg = 0;
		end;
		agg = agg + _&G_CONST_VAR_VALUE.;
		if (last.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			output;
		end;
	run;
	%&RSUDS.Unprotect(&ids_input_ds.)
%mend Aggregate_Sum;

%macro Aggregate_Prod(ids_input_ds =
							, ods_output_ds =
							, i_by_layers =);
	%&RSUDS.Protect(&ids_input_ds.)
	data &ods_output_ds.;
		set &ids_input_ds.;
		by
			&i_by_layers.
			&G_CONST_VAR_VARIABLE_REF_NAME.
		;
		retain agg;
		if (first.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			agg = 1;
		end;
		agg = agg * _&G_CONST_VAR_VALUE.;
		if (last.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			output;
		end;
	run;
	%&RSUDS.Unprotect(&ids_input_ds.)
%mend Aggregate_Prod;

%macro Aggregate_Avg(ids_input_ds =
							, ods_output_ds =
							, i_by_layers =);
	%&RSUDS.Protect(&ids_input_ds.)
	data &ods_output_ds.;
		set &ids_input_ds.;
		by
			&i_by_layers.
			&G_CONST_VAR_VARIABLE_REF_NAME.
		;
		retain sum;
		retain count;
		if (first.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			sum = 0;
			count = 0;
		end;
		sum = sum + _&G_CONST_VAR_VALUE.;
		count = count + 1;
		if (last.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			agg = sum / count;
			output;
		end;
	run;
	%&RSUDS.Unprotect(&ids_input_ds.)
%mend Aggregate_Avg;

%macro Aggregate_Min(ids_input_ds =
							, ods_output_ds =
							, i_by_layers =);
	%&RSUDS.Protect(&ids_input_ds.)
	data &ods_output_ds.;
		set &ids_input_ds.;
		by
			&i_by_layers.
			&G_CONST_VAR_VARIABLE_REF_NAME.
		;
		retain agg;
		if (first.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			agg = _&G_CONST_VAR_VALUE.;
		end;
		if (_&G_CONST_VAR_VALUE. < agg) then do;
			agg = _&G_CONST_VAR_VALUE.;
		end;
		if (last.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			output;
		end;
	run;
	%&RSUDS.Unprotect(&ids_input_ds.)
%mend Aggregate_Min;

%macro Aggregate_Max(ids_input_ds =
							, ods_output_ds =
							, i_by_layers =);
	%&RSUDS.Protect(&ids_input_ds.)
	data &ods_output_ds.;
		set &ids_input_ds.;
		by
			&i_by_layers.
			&G_CONST_VAR_VARIABLE_REF_NAME.
		;
		retain agg;
		if (first.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			agg = _&G_CONST_VAR_VALUE.;
		end;
		if (agg < _&G_CONST_VAR_VALUE.) then do;
			agg = _&G_CONST_VAR_VALUE.;
		end;
		if (last.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			output;
		end;
	run;
	%&RSUDS.Unprotect(&ids_input_ds.)
%mend Aggregate_Max;

%macro Aggregate_Count(ids_input_ds =
							, ods_output_ds =
							, i_by_layers =);
	%&RSUDS.Protect(&ids_input_ds.)
	data &ods_output_ds.;
		set &ids_input_ds.;
		by
			&i_by_layers.
			&G_CONST_VAR_VARIABLE_REF_NAME.
		;
		retain agg;
		if (first.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			agg = 0;
		end;
		agg = agg + 1;
		if (last.&G_CONST_VAR_VARIABLE_REF_NAME.) then do;
			output;
		end;
	run;
	%&RSUDS.Unprotect(&ids_input_ds.)
%mend Aggregate_Count;