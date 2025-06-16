/******************************************************/
/* Dimension.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: Axisの合成
/******************************************************/
%RSUSetConstant(Dimension, Dim__);
%RSUSetConstant(G_CONST_VAR_ADDRESS, dimension_address)

/**========================================**/
/* 空間、時間、シナリオをCross-Join
/**========================================**/
%macro Dim__Construct(i_formula_set_id =
							, i_data_index =
							, ods_dimension =);
	%local /readonly _TMP_DS_COMPSITE_AXIS_SPACE = %&RSUDS.GetTempDSName(axis_composit_sp);
	%&AxisSpace.Compose(i_formula_set_id = &i_formula_set_id.
							, i_data_index = &i_data_index.
							, ods_composite_axis = &_TMP_DS_COMPSITE_AXIS_SPACE.)
	%local /readonly _TMP_DS_AXIS_SCENARIO = %&RSUDS.GetTempDSName(layer_scenario);
	%&AxisScenario.Compose(i_formula_set_id = &i_formula_set_id.
								, i_data_index = &i_data_index.
								, ods_composite_axis = &_TMP_DS_AXIS_SCENARIO.)
	%local /readonly _TMP_DS_AXIS_TIME = %&RSUDS.GetTempDSName(layer_time);
	%&AxisTime.Compose(i_formula_set_id = &i_formula_set_id.
							, i_data_index = &i_data_index.
							, i_horizon_end = %&CalculationSetting.Get(i_key = horizon_end)
							, ods_composite_axis = &_TMP_DS_AXIS_TIME.)

	%local /readonly _ROLE_LIST = &G_CONST_VAR_ROLE_SPACE. &G_CONST_VAR_ROLE_SCENARIO. &G_CONST_VAR_ROLE_TIME.;
	%local _layer_product_info;
	%local _layer_ds;
	%local _index_layer_ds;
	%local _layer_role;
	%&RSUDS.Delete(&ods_dimension.)
	%local _no_of_elements_rep;
	%local _no_of_layer_elements;
	%do %while(%&RSUUtil.ForEach(i_items = &_TMP_DS_COMPSITE_AXIS_SPACE. &_TMP_DS_AXIS_SCENARIO. &_TMP_DS_AXIS_TIME.
										, ovar_item = _layer_ds
										, iovar_index = _index_layer_ds));
		%if (%&RSUDS.Exists(&_layer_ds.)) %then %do;
			%let _layer_role = %sysfunc(scan(&_ROLE_LIST., &_index_layer_ds., %str( )));
			%&RSUDS.Let(i_query = &_layer_ds.
							, ods_dest_ds = WORK.tmp_layer)
			%&RSUText.Append(iovar_base = _layer_product_info
								, i_append_text = (&_layer_role.)
								, i_delimiter = %str( x ))
			%if (not %&RSUDS.Exists(&ods_dimension.)) %then %do;
				%&RSUDS.Let(i_query = WORK.tmp_layer
								, ods_dest_ds = &ods_dimension.)
			%end;
			%else %do;
				%&RSUDS.CrossJoin(ids_lhs_ds = &ods_dimension.
									, ids_rhs_ds = WORK.tmp_layer)
			%end;
			%let _no_of_layer_elements = %&RSUDS.GetCount(WORK.tmp_layer);
			%&RSUText.Append(iovar_base = _no_of_elements_rep
								, i_append_text = &_no_of_layer_elements.
								, i_delimiter = %str( x ))
			%&RSUDS.Delete(WORK.tmp_layer)
		%end;
	%end;
	%&RSUDS.Delete(&_TMP_DS_COMPSITE_AXIS_SPACE. &_TMP_DS_AXIS_SCENARIO. &_TMP_DS_AXIS_TIME.)
	%let _no_of_layer_elements = %&RSUDS.GetCount(&ods_dimension.);
	%&RSUText.Append(iovar_base = _no_of_elements_rep
						, i_append_text = &_no_of_layer_elements.
						, i_delimiter = %str( = ))
	%&RSULogger.PutInfo(Layer structucture: &_layer_product_info.)
	%&RSULogger.PutInfo(# of layer elements: &_no_of_elements_rep.)

	/* Dimension */
	%local _data_index_in;
	%local _dsid_data_id;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_FORMULA_EVAL.(where = (formula_set_id = "&i_formula_set_id."))
										, i_vars = _data_index_in:data_index_in
										, ovar_dsid = _dsid_data_id));
		%AssignAddressTemplate(iods_full_layer = &ods_dimension.
									, i_data_index = &_data_index_in.)
	%end;
	%AssignAddress(iods_full_layer = &ods_dimension.
						, i_data_index = &i_data_index.)
%mend Dim__Construct;

%macro AssignAddressTemplate(iods_full_layer =
									, i_data_index =);
	data &iods_full_layer.(drop = _time_wild_card  &G_CONST_VAR_COORDINATE._&i_data_index._:);
		set &iods_full_layer.;
		attrib
			address_&i_data_index. length = $14.
			_time_wild_card length = $1.
		;
		format
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SPACE.
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SCENARIO.
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_TIME.
		;
		if (missing(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SPACE.)) then do;
			_time_wild_card = '@';
		end;
		address_&i_data_index. = catx(';'
												, coalescec(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SPACE., '.')
												, coalescec(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SCENARIO., '.')
												, coalescec(_time_wild_card, '.'));
	run;
	quit;
%mend AssignAddressTemplate;

%macro AssignAddress(iods_full_layer =
							, i_data_index =);
	data &iods_full_layer.(drop = _time_wild_card &G_CONST_VAR_COORDINATE._:);
		attrib
			address length = $14.
		;
		set &iods_full_layer.;
		attrib
			address_&i_data_index. length = $14.
			_time_wild_card length = $1.
		;
		format
			&G_CONST_VAR_COORDINATE_SPACE.
			&G_CONST_VAR_COORDINATE_SCENARIO.
			&G_CONST_VAR_COORDINATE_TIME.
		;
		if (missing(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SPACE.)) then do;
			_time_wild_card = '@';
		end;
		address_&i_data_index. = catx(';'
												, coalescec(&G_CONST_VAR_COORDINATE_SPACE., '.')
												, coalescec(&G_CONST_VAR_COORDINATE_SCENARIO., '.')
												, coalescec(_time_wild_card, '.'));
		address = catx(';'
							, coalescec(&G_CONST_VAR_COORDINATE_SPACE., '.')
							, coalescec(&G_CONST_VAR_COORDINATE_SCENARIO., '.')
							, coalescec(&G_CONST_VAR_COORDINATE_TIME., '.'));
	run;
	quit;
%mend AssignAddress;

/**=============================**/
/* 番地付与
/**=============================**/
%macro Dim__AssignAddress(i_data_id =
								, i_data_index =);
	%local /readonly _TMP_DS_DATA_DS = %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
	%&RSULogger.PutNote(Assigning address to &_TMP_DS_DATA_DS.)
	data &_TMP_DS_DATA_DS.(drop = &G_CONST_VAR_COORDINATE._&i_data_index._:);
		attrib
			&G_CONST_VAR_ADDRESS._&i_data_index. legnth = $20.
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SPACE. length = $&G_CONST_COORDINATE_LEN_SPACE..
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SCENARIO. length = $&G_CONST_COORDINATE_LEN_SCENARIO..
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_TIME. length = $&G_CONST_COORDINATE_LEN_TIME..
		;
		set &_TMP_DS_DATA_DS.;
		&G_CONST_VAR_ADDRESS._&i_data_index. = catx(';'
																	, coalescec(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SPACE., '.')
																	, coalescec(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SCENARIO., '.')
																	, coalescec(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_TIME., '.'));
	run;
	quit;
%mend Dim__AssignAddress;

%macro Dim__JoinToVariablePart(i_data_id =
										, ods_layer_variable_obj =);
	%&RSULogger.PutNote(Joining variable part and layer part)
	%local /readonly _TMP_DS_VARIABLE_PART = %&VariableData.GetDSObject(i_data_id = &i_data_id.);
	%local /readonly _TMP_DS_LAYER_PART = %&Layer.GetDSObject(i_data_id = &i_data_id.);

	data &_TMP_DS_VARIABLE_PART.;
		set &_TMP_DS_VARIABLE_PART.;
		attrib
			&G_CONST_VAR_ADDRESS. length = $20.
		;
		&G_CONST_VAR_ADDRESS. = substr(&G_CONST_VAR_VALUE_KEY., 1, 14);
	run;
	quit;

	data &ods_layer_variable_obj.(drop = _rc);
		if (_N_ = 0) then do;
			set &_TMP_DS_VARIABLE_PART.;
		end;
		set &_TMP_DS_LAYER_PART.;
		if (_N_ = 1) then do;
			declare hash hh_variable(dataset: "&_TMP_DS_VARIABLE_PART.", multidata: 'yes');
			_rc = hh_variable.definekey("&G_CONST_VAR_ADDRESS.");
			_rc = hh_variable.definedata("&G_CONST_VAR_VALUE.");
			_rc = hh_variable.definedone();
		end;
		_rc = hh_variable.find();
		if (_rc = 0) then do;
			output;
			_rc = hh_value.find_nex();
			do (_rc = 0) then do;
				output;
				_rc = hh_value.find_nex();
			end;
		end;
	run;
	quit;
%mend Dim__JoinToVariablePart;

%macro CompositeAxis(ids_axis_space =
							, ids_axis_scenario =
							, ids_axis_time =
							, ods_dimension_object =);
	%&RSULogger.PutNote(Composing dimesion object from axis objects)
	%&RSUDS.Delete(&ods_dimension_object.)
	%local _ds_axis;
	%local _index_axis;
	%local _axis_product_info;
	%local _axis_product_elements_info;
	%local _axis_index;
	%local _no_of_elements;
	%do %while(%&RSUUtil.ForEach(i_items = &ids_axis_space. &ids_axis_scenario. &ids_axis_time.
										, ovar_item = _ds_axis
										, iovar_index = _index_axis));
		%let _axis_index = %eval(&_axis_index. + 1);
		%let _axis_type = %scan(&G_CONST_AXIS_TYPE_LIST., &_axis_index.);
		%if (%&RSUDS.Exists(&_ds_axis.)) %then %do;
			%&RSUDS.CrossJoin(ids_lhs_ds = &ods_dimension_object.
								, ids_rhs_ds = &_ds_axis.)
			%local _no_of_elements = %&RSUDS.GetCount(&_ds_axis.);
			%&RSUText.Append(iovar_base = _axix_product_info
								, i_append_text = (&_axis_type.)
								, i_delimiter = %str( x ))
			%&RSUText.Append(iovar_base = _axis_product_elements_info
								, i_append_text = &_no_of_elements.
								, i_delimiter = %str( x ))
		%end;
	%end;
	%let _no_of_elements = %&RSUDS.GetCount(&ods_dimension_object.);
	%&RSUText.Append(iovar_base = _axis_product_elements_info
						, i_append_text = &_no_of_elements.
						, i_delimiter = %str( = ))
	%&RSULogger.PutBlock([Axis-Product information]
							, &_axix_product_info.
							, &_axis_product_elements_info.)
%mend CompositeAxis;
