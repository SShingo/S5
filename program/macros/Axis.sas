/******************************************************/
/* Axis.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/******************************************************/
%RSUSetConstant(Axis, Axis__)
%RSUSetConstant(G_CONST_VAR_COORDINATE, axis_coordinate)
%RSUSetConstant(G_CONST_VAR_COORDINATE_SPACE, axis_coordinate_space)
%RSUSetConstant(G_CONST_VAR_COORDINATE_SCENARIO, axis_coordinate_scenario)
%RSUSetConstant(G_CONST_VAR_COORDINATE_TIME, axis_coordinate_time)
%RSUSetConstant(G_CONST_COORDINATE_LEN_SPACE, 7)
%RSUSetConstant(G_CONST_COORDINATE_LEN_SCENARIO, 3)
%RSUSetConstant(G_CONST_COORDINATE_LEN_TIME, 2)
%RSUSetConstant(G_CONST_AXIS_OBJ_NAME_BODY, axis)

/**======================================**/
/* データをAxixに分解
/**======================================**/
%macro Axis__CreateAxis(i_data_id =
								, i_data_index =
								, ids_source_ds =);
	%&RSULogger.PutNote(Decomposing data "&i_data_id." into each type of axis.)
	%local _axis_type;
	%local _index_axis_type;
	%local _axis_variable;
	%local _dsid_axis_vaiable;
	%local _variables_for_axis;
	%local _search_axis_variable_code;
	%local /readonly _TMP_DS_ELEMENTS_IN_AXIS = %&RSUDS.GetTempDSName(elements_in_axis);
	%local _ds_target_axis;
	%do %while(%&RSUUtil.ForEach(i_items = &G_CONST_VAR_ROLE_SPACE. &G_CONST_VAR_ROLE_SCENARIO. &G_CONST_VAR_ROLE_TIME.
										, ovar_item = _axis_type
										, iovar_index = _index_axis_type));
		%let _ds_target_axis = %DSAxis(i_data_index = &i_data_index.
												, i_axis_type = &_axis_type.);
		%let _variables_for_axis =;
		%if (&_axis_type. = &G_CONST_VAR_ROLE_SPACE.) %then %do;
			%let _search_axis_variable_code = (variable_role = "&G_CONST_VAR_ROLE_SPACE." or variable_role = "&G_CONST_VAR_ROLE_FORMULA_SYS_ID.");
		%end;
		%else %do;
			%let _search_axis_variable_code = variable_role = "&_axis_type.";
		%end; 
		%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_VAR_DEF.(where = (data_id = "&i_data_id." and &_search_axis_variable_code.))
											, i_vars = _axis_variable:variable_name
											, ovar_dsid = _dsid_axis_vaiable));
			%&RSUText.Append(iovar_base = _variables_for_axis
								, i_append_text = &_axis_variable.)
		%end;
		%if (%&RSUUtil.IsMacroBlank(_variables_for_axis)) %then %do;
			%&RSULogger.PutInfo(No &_axis_type. variable in this data)
		%end;
		%else %do;
			%&RSULogger.PutBlock([Axis data set]
										, Target dataset: &i_data_id.
										, Axis dataset: &_ds_target_axis.
										, Variables: &_variables_for_axis.)
			%&RSUDS.GetUniqueList(i_query = &ids_source_ds.(keep = &_variables_for_axis.)
										, i_by_variables = &_variables_for_axis.
										, ods_output_ds = &_TMP_DS_ELEMENTS_IN_AXIS.)
			data &_ds_target_axis.;
				attrib
					&G_CONST_VAR_COORDINATE._&i_data_index._&_axis_type. length = $&&&G_CONST_COORDINATE_LEN_&_axis_type...;
				;
				set &_TMP_DS_ELEMENTS_IN_AXIS.(keep = &_variables_for_axis.);
				&G_CONST_VAR_COORDINATE._&i_data_index._&_axis_type. = put(_N_ - 1, HEX&&&G_CONST_COORDINATE_LEN_&_axis_type...);
			run;
			quit;
			%&RSUDS.Delete(&_TMP_DS_ELEMENTS_IN_AXIS.)
			%&RSUDS.SetLabel(iods_target_ds = &_ds_target_axis. 
								, i_label = &i_data_id. (&_axis_type.))			
			%DecodeLayer(i_data_id = &i_data_id
							, i_data_index = &i_data_index.
							, i_axis_type = &_axis_type.
							, i_variables_in_axis = &_variables_for_axis.)
		%end;
	%end;
%mend Axis__CreateAxis;

/**---------------------------------------**/
/* 元データのレイヤー情報を軸情報に変換
/**---------------------------------------**/
%macro DecodeLayer(i_data_id =
						, i_data_index =
						, i_axis_type =
						, i_variables_in_axis =);
	%local /readonly _TARGET_DATA_DS = %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
	%local /readonly _TARGET_AXIS_DS = %DSAxis(i_data_index = &i_data_index.
															, i_axis_type = &i_axis_type.);
	%&RSULogger.PutNote(Decoding layer in "&_TARGET_DATA_DS." by "&_TARGET_AXIS_DS.");
	%local _variable_in_axis;
	%local _index_variable_in_axis;
	data &_TARGET_DATA_DS.(drop = _rc &i_variables_in_axis.);
		if (_N_ = 0) then do;
			set &_TARGET_AXIS_DS.;
		end;
		set &_TARGET_DATA_DS.;
		if (_N_ = 1) then do;
			declare hash hh_axis(dataset: "&_TARGET_AXIS_DS");
	%do %while(%&RSUUtil.ForEach(i_items = &i_variables_in_axis.
										, ovar_item = _variable_in_axis
										, iovar_index = _index_variable_in_axis));
			_rc = hh_axis.definekey("&_variable_in_axis.");
	%end;
			_rc = hh_axis.definedata("&G_CONST_VAR_COORDINATE._&i_data_index._&_axis_type.");
			_rc = hh_axis.definedone();
		end;
		_rc = hh_axis.find();
	run;
	quit;
%mend DecodeLayer;

/**===================================**/
/* 同じタイプのAxisをジョイン
/**===================================**/
%macro Axis__JoinAxes(iods_joined_axis =
							, ids_axis =);
	%&RSULogger.PutNote(Joining axis "&ids_axis.".)
	%if (%&RSUDS.Exists(&iods_joined_axis.)) %then %do;
		%local _array_vairables_in_axis;
		%&RSUDS.GetDSVariables(ids_dataset = &ids_axis.
									, i_regex_exclude = /&G_CONST_VAR_COORDINATE./
									, ovar_variables = _array_vairables_in_axis)
		%local _variable_in_axis;
		%local _index_variable_in_axis;
		%local _inner_join_condition_code;
		%local _already_exists;
		%let _already_exists = %&RSUBool.False;
		%do %while(%&RSUUtil.ForEach(i_items = &_array_vairables_in_axis.
											, ovar_item = _variable_in_axis
											, iovar_index = _index_variable_in_axis));
			%if (%&RSUDS.IsVarDefined(ids_dataset = &iods_joined_axis., i_var_name = &_variable_in_axis.)) %then %do;
				%&RSUText.Append(iovar_base = _inner_join_condition_code
									, i_append_text = &_variable_in_axis.:&_variable_in_axis.)
				%let _already_exists = %&RSUBool.True;
			%end;
		%end;
		%if (&_already_exists.) %then %do;
			/* 共通変数がある場合はInnerJoin */
			%&RSULogger.PutInfo(Axis "&_ds_axis.": Variables registered already. Inner joined.(&_inner_join_condition_code.))
			%&RSUDS.InnerJoin(ids_lhs_ds = &ods_joined_axis.
									, ids_rhs_ds = &_ds_axis.
									, i_conditions = &_inner_join_condition_code.)
		%end;
		%else %do;
			/* 共通変数がない場合はCrossJoin */
			%&RSULogger.PutInfo(All variables in "&_ds_axis." are no registered yet. Cross joined.)
			%&RSUDS.CrossJoin(ids_lhs_ds = &ods_joined_axis.
									, ids_rhs_ds = &_ds_axis.)
		%end;
	%end;
	%else %do;
		%&RSULogger.PutInfo(Axis "&_ds_axis.": this is the 1st axis. Use id as it is)
		%&RSUDS.Let(i_query = &_ds_axis.
						, ods_dest_ds = &ods_joined_axis.)
	%end;
	%&RSUDS.Delete(&_TMP_DS_TARGET_LAYER.)
%mend Axis__JoinAxes;

/**===================================**/
/* 軸収集・連結
/**===================================**/
%macro Axis__GatherAxis(i_data_id =
								, iods_gathered_layers =
								, ids_layer_ds =);
	%local /readonly _TMP_DS_TARGET_LAYER = %&RSUDS.GetTempDSName(target_layer);
	%&RSUDS.Let(i_query = &ids_layer_ds.
					, ods_dest_ds = &_TMP_DS_TARGET_LAYER.)
	%if (%&RSUDS.Exists(&iods_gathered_layers.)) %then %do;
		%local _array_new_layer_variables;
		%&RSUDS.GetDSVariables(ids_dataset = &_TMP_DS_TARGET_LAYER.
									, ovar_variables = _array_new_layer_variables)
		%local _layer_in_new_data;
		%local _index_layer_in_new_data;
		%local _inner_join_condition_code;
		%local _joined_layers;
		%local _already_exists;
		%let _already_exists = %&RSUBool.False;
		%do %while(%&RSUUtil.ForEach(i_items = &_array_new_layer_variables.
											, ovar_item = _layer_in_new_data
											, iovar_index = _index_layer_in_new_data));
			%if (%&RSUDS.IsVarDefined(ids_dataset = &iods_gathered_layers., i_var_name = &_layer_in_new_data.)) %then %do;
				%&RSUText.Append(iovar_base = _inner_join_condition_code
									, i_append_text = &_layer_in_new_data.:&_layer_in_new_data.)
				%&RSUText.Append(iovar_base = _joined_layers
									, i_append_text = &_layer_in_new_data.)
				%let _already_exists = %&RSUBool.True;
			%end;
		%end;
		%if (&_already_exists.) %then %do;
			/* 共通変数がある場合はInnerJoin */
			%&RSULogger.PutInfo(Input Axis "&i_data_id.": Layer(s) (&_joined_layers.) registered already. Inner joined.(&_inner_join_condition_code.))
			%&RSUDS.InnerJoin(ids_lhs_ds = &iods_gathered_layers.
									, ids_rhs_ds = &_TMP_DS_TARGET_LAYER.
									, i_conditions = &_inner_join_condition_code.)
		%end;
		%else %do;
			/* 共通変数がない場合はCrossJoin */
			%&RSULogger.PutInfo(All axis in "&i_data_id." are no registered yet. Cross joined.)
			%&RSUDS.CrossJoin(ids_lhs_ds = &iods_gathered_layers.
									, ids_rhs_ds = &_TMP_DS_TARGET_LAYER.)
		%end;
	%end;
	%else %do;
		%&RSULogger.PutInfo(Input axis "&i_data_id.": this is the 1st layer data. Use id as it is)
		%&RSUDS.Let(i_query = &_TMP_DS_TARGET_LAYER.
						, ods_dest_ds = &iods_gathered_layers.)
	%end;
	%&RSUDS.Delete(&_TMP_DS_TARGET_LAYER.)
%mend Axis__GatherAxis;

%macro DSAxis(i_data_index =
				, i_axis_type =);
	&G_CONST_LIB_WORK..Axis_&i_data_index._&i_axis_type.
%mend DSAxis;