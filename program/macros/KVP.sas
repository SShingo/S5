/****************************************************************/
/* KVP.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: すべてのデータをKey-Value pairとして扱う
/* NOTE: Keyの構成（20 byte）
/* NOTE: XXXXXXX;XXX;XX;XXXXX
/* NOTE: 	第1成分: 空間座標 16進7桁
/* NOTE: 	第2成分: シナリオ座標 16進3桁
/* NOTE:		第3成分: 時間座標 16進2桁
/* NOTE: 	第4成分: 属性コード 6桁の文字列。2桁のデータセット番号と3桁の属性コード
/* NOTE: Valueの構成
/* NOTE: 	日本語文字列値の場合もあるので、200 byte文字列とする
/****************************************************************/
%RSUSetConstant(KVP, KVP__)
%RSUSetConstant(G_CONST_VARIABLE_KEY_LEN, 20)
%RSUSetConstant(G_CONST_VARIABLE_KEY, variable_key)

%macro KVP__Create(i_data_id =
						, i_data_index =
						, iods_source_ds =);
	%&RSULogger.PutNote(Making data "&iods_source_ds." into key-value pair format)
	data &iods_source_ds.(keep = &G_CONST_VARIABLE_KEY. &G_CONST_VAR_VALUE.);
		attrib
			&G_CONST_VARIABLE_KEY. length = $&G_CONST_VARIABLE_KEY_LEN..
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SPACE. length = $&G_CONST_COORDINATE_LEN_SPACE..
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SCENARIO. length = $&G_CONST_COORDINATE_LEN_SCENARIO..
			&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_TIME. length = $&G_CONST_COORDINATE_LEN_TIME..
		;
		set &iods_source_ds.;
		&G_CONST_VARIABLE_KEY. = catx(';'
												, coalescec(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SPACE., '.')
												, coalescec(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_SCENARIO., '.')
												, coalescec(&G_CONST_VAR_COORDINATE._&i_data_index._&G_CONST_VAR_ROLE_TIME., '.')
												, &G_CONST_VAR_VARIABLE_CODE.);
	run;
	quit;

	%&RSUDS.Move(i_query = &iods_source_ds.
					, ods_dest_ds = %&DataObject.DSVariablePart(i_suffix = &i_data_index.))
	%&RSUDS.SetLabel(iods_target_ds = %&DataObject.DSVariablePart(i_suffix = &i_data_index.)
						, i_label = &i_data_id.)
%mend KVP__Create;

%macro CreatePrimaryKeyMapSpace(i_data_id =
										, i_variables =);
	%&RSULogger.PutNote(Createing primary key map for "&i_data_id.")
	%&RSULogger.PutBlock(Role: space & formula system id
								, Variables: &i_variables.)
	%if (%&RSUUtil.IsMacroBlank(i_variables)) %then %do;
		%&RSULogger.PutInfo(No space vairables in "&i_data_id.")
		%return;
	%end;
	%&RSUDS.GetUniqueList(i_query = %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(keep = &i_variables.)
								, i_by_variables = &i_variables.
								, ods_output_ds = %DSPrimaryKeyMap(i_primary_key = sp_&i_data_id.))
	data %DSPrimaryKeyMap(i_primary_key = sp_&i_data_id.);
		attrib
			&G_CONST_VAR_COORDINATE. length = $7.
		;
		set %DSPrimaryKeyMap(i_primary_key = sp_&i_data_id.);
		&G_CONST_VAR_COORDINATE. = put(_N_ - 1, HEX7.);
	run;
	quit;
%mend CreatePrimaryKeyMapSpace;

%macro CreatePrimaryKeyMapScenario(i_data_id =
											, i_variables =);
	%&RSULogger.PutNote(Createing primary key map for "&i_data_id.")
	%&RSULogger.PutBlock(Role: scenario
								, Variables: &i_variables.)
	%if (%&RSUUtil.IsMacroBlank(i_variables)) %then %do;
		%&RSULogger.PutInfo(No scenario vairables in "&i_data_id.")
		%return;
	%end;
	%&RSUDS.GetUniqueList(i_query = %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(keep = &i_variables.)
								, i_by_variables = &i_variables.
								, ods_output_ds = %DSPrimaryKeyMap(i_primary_key = sc_&i_data_id.))
	data %DSPrimaryKeyMap(i_primary_key = sc_&i_data_id.);
		attrib
			&G_CONST_VAR_COORDINATE. length = $3.
		;
		set %DSPrimaryKeyMap(i_primary_key = sc_&i_data_id.);
		&G_CONST_VAR_COORDINATE. = put(_N_ - 1, HEX3.);
	run;
	quit;
%mend CreatePrimaryKeyMapScenario;

%macro CreatePrimaryKeyMapTime(i_data_id =
										, i_variables =
										, i_horizon_as_of =);
	%&RSULogger.PutNote(Createing primary key map for time)
	%if (%&RSUUtil.IsMacroBlank(i_variables)) %then %do;
		%&RSULogger.PutInfo(No time vairables in "&i_data_id.")
		%return;
	%end;
	%if (&i_variables. ne &G_CONST_VAR_TIME.) %then %do;
		%&RSUError.Throw(Invalid time variable "&i_variables.")
		%return;
	%end;
	%local /readonly _TMP_DS_TIME_IN_DATA = %&RSUDS.GetTempDSName(time_in_data);
	%&RSUDS.Let(i_query = %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(keep = &i_variables.)
					, ods_dest_ds = &_TMP_DS_TIME_IN_DATA.)
	data &_TMP_DS_TIME_IN_DATA.;
		set &_TMP_DS_TIME_IN_DATA. end = eof;
		if (eof) then do;
			&G_CONST_VAR_TIME. = &i_horizon_as_of.;
		end;
	run;
	quit;

	%&RSUDS.GetUniqueList(i_query = &_TMP_DS_TIME_IN_DATA.
								, i_by_variables = &i_variables.
								, ods_output_ds = &_TMP_DS_TIME_IN_DATA.)
	data %DSPrimaryKeyMap(i_primary_key = ti_&i_data_id.)(drop = _rc);
		if (_N_ = 0) then do;
			set %DSPrimaryKeyMap(i_primary_key = ti_&G_CONST_VAR_ROLE_TIME.);
		end;
		set &_TMP_DS_TIME_IN_DATA.;
		if (_N_ = 1) then do;
			declare hash hh_time(dataset: "%DSPrimaryKeyMap(i_primary_key = ti_&G_CONST_VAR_ROLE_TIME.)");
			_rc = hh_time.definekey("&G_CONST_VAR_TIME.");
			_rc = hh_time.definedata("&G_CONST_VAR_HORIZON_INDEX.");
			_rc = hh_time.definedata("&G_CONST_VAR_COORDINATE.");
			_rc = hh_time.definedone();
		end;
		_rc = hh_time.find();
	run;
	quit;
%mend CreatePrimaryKeyMapTime;

%macro CreatePrimaryKeyMapTimeAll(ids_time_source =
											, i_horizon_as_of =);
	%&RSULogger.PutNote(Createing primary key map for all time)
	%&RSUDS.GetUniqueList(i_query = &ids_time_source.
								, i_by_variables = &G_CONST_VAR_TIME.
								, ods_output_ds = &ids_time_source.)
	%local _index_of_as_of;
	data _null_;
		set &ids_time_source.;
		if (&G_CONST_VAR_TIME. = "&i_horizon_as_of") then do;
			call symputx('_index_of_as_of', _N_);
		end;
	run;
	quit;

	/* Axis */
	data %DSPrimaryKeyMap(i_primary_key = ti_&G_CONST_VAR_ROLE_TIME.);
		attrib
			&G_CONST_VAR_TIME. length = $8. label = "&G_SETTING_TIME_VARIABLE_NAME."
			&G_CONST_VAR_HORIZON_INDEX. length = $3. label = "&G_SETTING_TIME_IDX_VARIABLE_NAME."
			&G_CONST_VAR_COORDINATE. length = $2.
		;
		set &ids_time_source.;
		&G_CONST_VAR_HORIZON_INDEX. = _N_ - &_index_of_as_of.;
		&G_CONST_VAR_COORDINATE. = put(_N_ - 1, HEX2.);
	run;

	/* Dimension */
	data %DSDim(i_name = &G_CONST_VAR_ROLE_TIME.)(drop = &G_CONST_VAR_COORDINATE.);
		attrib
			address length = $20.
		;
		set %DSPrimaryKeyMap(i_primary_key = ti_&G_CONST_VAR_ROLE_TIME.);
		address = catx(';', '.', '.', &G_CONST_VAR_COORDINATE.);
	run;
	quit;

	/* Data */
	proc transpose data = %DSPrimaryKeyMap(i_primary_key = ti_&G_CONST_VAR_ROLE_TIME.) out = %&DataObject.DSVariablePart(i_suffix = &G_CONST_VAR_ROLE_TIME.)(rename = (_LABEL_ = &G_CONST_VAR_VARIABLE_REF_NAME. COL1 = &G_CONST_VAR_VALUE.) drop = _NAME_);
		by
			&G_CONST_VAR_COORDINATE.
		;
		var
			&G_CONST_VAR_TIME.
			&G_CONST_VAR_HORIZON_INDEX.
		;
	run;
	quit;

	data %&DataObject.DSVariablePart(i_suffix = &G_CONST_VAR_ROLE_TIME.)(drop = &G_CONST_VAR_COORDINATE.);
		set %&DataObject.DSVariablePart(i_suffix = &G_CONST_VAR_ROLE_TIME.);
		attrib
			address length = $20.
		;
		address = catx(';', '.', '.', &G_CONST_VAR_COORDINATE.);
	run;
	quit;
%mend CreatePrimaryKeyMapTimeAll;

%macro ConvertVariablesToCode(i_data_id =
										, i_data_id_index =);
	%&RSULogger.PutNote(Converting physical primary key to code of "&i_data_id.")
	/* Space */
	%ConvertVariablesToCodeSpace(i_data_id = &i_data_id.)
	/* Scenario */
	%ConvertVariablesToCodeScenario(i_data_id = &i_data_id.)
	/* Time */
	%ConvertVariablesToCodeTime(i_data_id = &i_data_id.)

	data %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(drop = coordinate_sp coordinate_sc coordinate_ti);
		attrib
			address length = $20.
		;
		set %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
		address = catx(';', coordinate_sp, coordinate_sc, coordinate_ti);
	run;
	quit;

	/* Variable */
	%ConvertVariableNameToCode(i_data_id = &i_data_id.
										, i_data_id_index = &i_data_id_index.)
%mend ConvertVariablesToCode;

%macro ConvertVariablesToCodeSpace(i_data_id =);
	%local /readonly _SPACE_VAR = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&i_data_id.")), i_variable = &G_CONST_VAR_ROLE_SPACE.);
	%local /readonly _FORMULA_SYSTEM_ID_VAR = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&i_data_id.")), i_variable = &G_CONST_VAR_ROLE_FORMULA_SYS_ID.);
	%local /readonly _TARGET_VAR = &_SPACE_VAR. &_FORMULA_SYSTEM_ID_VAR.;
	%if (%&RSUUtil.IsMacroBlank(_TARGET_VAR)) %then %do;
		%&RSULogger.PutInfo(No space vairables in "&i_data_id.")
		%return;
	%end;
	%local /readonly _TMP_DS_TARGET_PM = %DSPrimaryKeyMap(i_primary_key = sp_&i_data_id.);
	%local _join_var;
	%local _index_join_var;
	data %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(drop = _rc &_TARGET_VAR. address);
		if (_N_ = 0) then do;
			set &_TMP_DS_TARGET_PM.;
		end;
		set %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
		if (_N_ = 1) then do;
			declare hash hh_pm(dataset: "&_TMP_DS_TARGET_PM.");
	%do %while(%&RSUUtil.ForEach(i_items = &_TARGET_VAR.
										, ovar_item = _join_var
										, iovar_index = _index_join_var));
			_rc = hh_pm.definekey("&_join_var.");
	%end;
			_rc = hh_pm.definedata('address');
			_rc = hh_pm.definedone();
		end;
		attrib
			coordinate_sp length = $7.
		;
		_rc = hh_pm.find();
		coordinate_sp = scan(address, 1, ';');
	run;
	quit;
%mend ConvertVariablesToCodeSpace;

%macro ConvertVariablesToCodeScenario(i_data_id =);
	%local /readonly _SCENARIO_VAR = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&i_data_id.")), i_variable = &G_CONST_VAR_ROLE_SCENARIO);
	%if (%&RSUUtil.IsMacroBlank(_SCENARIO_VAR)) %then %do;
		%&RSULogger.PutInfo(No scenario vairables in "&i_data_id.")
		%return;
	%end;
	%local /readonly _TMP_DS_TARGET_PM = %DSPrimaryKeyMap(i_primary_key = sc_&i_data_id.);
	%local _join_var;
	%local _index_join_var;
	data %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(drop = _rc &_SCENARIO_VAR. address);
		if (_N_ = 0) then do;
			set &_TMP_DS_TARGET_PM.;
		end;
		set %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
		if (_N_ = 1) then do;
			declare hash hh_pm(dataset: "&_TMP_DS_TARGET_PM.");
	%do %while(%&RSUUtil.ForEach(i_items = &_SCENARIO_VAR.
										, ovar_item = _join_var
										, iovar_index = _index_join_var));
			_rc = hh_pm.definekey("&_join_var.");
	%end;
			_rc = hh_pm.definedata('address');
			_rc = hh_pm.definedone();
		end;
		attrib
			coordinate_sc length = $3.
		;
		_rc = hh_pm.find();
		coordinate_sp = scan(address, 2, ';');
	run;
	quit;
%mend ConvertVariablesToCodeScenario;

%macro ConvertVariablesToCodeTime(i_data_id =);
	%local /readonly _TIME_VAR = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&i_data_id.")), i_variable = &G_CONST_VAR_ROLE_TIME);
	%if (%&RSUUtil.IsMacroBlank(_TIME_VAR)) %then %do;
		%&RSULogger.PutInfo(No time vairables in "&i_data_id.")
		%return;
	%end;
	%local /readonly _TMP_DS_TARGET_PM = %DSPrimaryKeyMap(i_primary_key = ti_&G_CONST_VAR_ROLE_TIME.);
	%local _join_var;
	%local _index_join_var;
	data %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(drop = _rc &_TIME_VAR. address);
		if (_N_ = 0) then do;
			set &_TMP_DS_TARGET_PM.;
		end;
		set %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
		if (_N_ = 1) then do;
			declare hash hh_pm(dataset: "&_TMP_DS_TARGET_PM.");
			_rc = hh_pm.definekey("&G_CONST_VAR_TIME.");
			_rc = hh_pm.definedata('address');
			_rc = hh_pm.definedone();
		end;
		attrib
			coordinate_ti length = $2.
		;
		_rc = hh_pm.find();
		coordinate_ti = scan(address, 3, ';');
	run;
	quit;
%mend ConvertVariablesToCodeTime;

%macro ConvertVariableNameToCode(i_data_id =
											, i_data_id_index =);
	%&RSULogger.PutNote(Conerting variable name to code in "&i_data_id.")
	%local /readonly _TMP_DS_VARIABLE_LIST = %&RSUDS.GetTempDSName(variable_list);
	%&RSUDS.GetUniqueList(i_query = %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(keep = &G_CONST_VAR_VARIABLE_REF_NAME.)
								, i_by_variables = &G_CONST_VAR_VARIABLE_REF_NAME.
								, ods_output_ds = &_TMP_DS_VARIABLE_LIST.)
	data &_TMP_DS_VARIABLE_LIST.(drop = _var_index);
		set &_TMP_DS_VARIABLE_LIST.;
		attrib
			var_code length = $5.
		;
		_var_index = _N_ - 1;
		var_code = cats(put(&i_data_id_index., HEX2.), put(_var_index, HEX3.));
	run;
	quit;

	data %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(drop = _rc &G_CONST_VAR_VARIABLE_REF_NAME. var_code);
		if (_N_ = 0) then do;
			set &_TMP_DS_VARIABLE_LIST.;
		end;
		set %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
		if (_N_ = 1) then do;
			declare hash hh_var(dataset: "&_TMP_DS_VARIABLE_LIST.");
			_rc = hh_var.definekey("&G_CONST_VAR_VARIABLE_REF_NAME.");
			_rc = hh_var.definedata("var_code");
			_rc = hh_var.definedone();
		end;
		_rc = hh_var.find();
		address = catx(';', address, var_code);
	run;
	quit;
	%&RSUDS.Move(i_query = &_TMP_DS_VARIABLE_LIST.
					, ods_dest_ds = %DSVarMap(i_data_id = &i_data_id.))
%mend ConvertVariableNameToCode;

/*-----------------------------------------------------------------------------------*/
/*	時間範囲制限
/*-----------------------------------------------------------------------------------*/
%macro LimitTimeRange(iods_input_ds =
							, i_time_range =
							, i_time_variable =
							, i_horizon_as_of =);
	%local /readonly _NO_OF_OBS_BEFORE = %&RSUDS.GetCount(&iods_input_ds.);
	%if (&i_time_range. = HISTORICAL) %then %do;
		%&RSULogger.PutNote(Limiting data to HISTORICAL range (&i_time_variable. <= &i_horizon_as_of.))
		data &iods_input_ds.;
			set &iods_input_ds.(where = (&i_time_variable. <= "&i_horizon_as_of."));
		run;
		quit;
	%end;
	%else %if (&i_time_range = FUTURE) %then %do;
		%&RSULogger.PutNote(Limiting data to FUTURE range (&i_time_variable. > &i_horizon_as_of.))
		data &iods_input_ds.;
			set &iods_input_ds.(where = ("&i_horizon_as_of." < &i_time_variable.));
		run;
		quit;
	%end;
	%else %do;
		%return;
	%end;
	%local /readonly _NO_OF_OBS_AFTER = %&RSUDS.GetCount(&iods_input_ds.);
	%&RSULogger.PutBlock(# of observation(s): &_NO_OF_OBS_BEFORE. >> &_NO_OF_OBS_AFTER.)
%mend LimitTimeRange;

%macro KVP__CreateFormulaVarMap(ids_formula_var_list =);
	%&RSUDS.GetUniqueList(i_query = &ids_formula_var_list.
								, i_by_variables = __tmp_decmp_formula_var
								, ods_output_ds = %DSVarMap(i_data_id = FORMULA))
	data %DSVarMap(i_data_id = FORMULA)(drop = var_index);
		set %DSVarMap(i_data_id = FORMULA);
		var_index = _N_ - 1;
		var_code = cats('00', put(var_index, HEX3.));
		rename
			__tmp_decmp_formula_var = &G_CONST_VARRIABLE_NAME_VALUE.
		;
	run;
	quit;
%mend KVP__CreateFormulaVarMap;

%macro KVP__CreateDimension(i_data_id =);
	%&RSULogger.PutNote(Building dimension of "&i_data_id.")
	%local /readonly _TMP_DIMENSION = %&RSUDS.GetTempDSName(dimension);
	data &_TMP_DIMENSION.;
		_dummy = 0;
	run;
	quit;
	%if (%&RSUDS.Exists(%DSPrimaryKeyMap(i_primary_key = sp_&i_data_id.))) %then %do;
		%&RSUDS.CrossJoin(ids_lhs_ds = &_TMP_DIMENSION.
								, ids_rhs_ds = %DSPrimaryKeyMap(i_primary_key = sp_&i_data_id.))
		%&RSUDS.Let(i_query = &_TMP_DIMENSION.(rename = &G_CONST_VAR_COORDINATE. = coord_sp)
						, ods_dest_ds = &_TMP_DIMENSION.)
	%end;
	%if (%&RSUDS.Exists(%DSPrimaryKeyMap(i_primary_key = sc_&i_data_id.))) %then %do;
		%&RSUDS.CrossJoin(ids_lhs_ds = &_TMP_DIMENSION.
								, ids_rhs_ds = %DSPrimaryKeyMap(i_primary_key = sc_&i_data_id.))
		%&RSUDS.Let(i_query = &_TMP_DIMENSION.(rename = &G_CONST_VAR_COORDINATE. = coord_sc)
						, ods_dest_ds =&_TMP_DIMENSION.)
	%end;
	%if (%&RSUDS.Exists(%DSPrimaryKeyMap(i_primary_key = ti_&i_data_id.))) %then %do;
		%&RSUDS.CrossJoin(ids_lhs_ds = &_TMP_DIMENSION.
								, ids_rhs_ds = %DSPrimaryKeyMap(i_primary_key = ti_&i_data_id.))
		%&RSUDS.Let(i_query = &_TMP_DIMENSION.(rename = &G_CONST_VAR_COORDINATE. = coord_ti)
						, ods_dest_ds = &_TMP_DIMENSION.)
	%end;
	data %DSDim(i_name = &i_data_id.)(drop = coord_:);
		attrib
			address length = $20.
		;
		set &_TMP_DIMENSION.(drop = _dummy);
		address = catx(';', coalescec(coord_sp, '.'), coalescec(coord_sc, '.'), coalescec(coord_ti, '.'));
	run;
	quit;
	%local /readonly _NO_OF_DIM_ELEMENT = %&RSUDS.GetCount(%DSDim(i_name = &i_data_id.));
	%&RSULogger.PutInfo(# of elements in dimension: &_NO_OF_DIM_ELEMENT.)
%mend KVP__CreateDimension;

%macro KVP__AssignAddress(i_data_id =);
	%&RSULogger.PutNote(Assigning address to input data "&i_data_id.")

	%local /readonly _TARGET_DIM = %DSDim(i_name = &i_data_id.);
	%local _join_keys;
	%&RSUDS.GetDSVariables(&_TARGET_DIM.
								, i_regex_exclude = /^(address)|(&G_CONST_VAR_HORIZON_INDEX)$/i
								, ovar_variables = _join_keys)
	%local _data_keys;
	%&RSUDS.GetDSVariables(&_TARGET_DIM.
								, i_regex_exclude = /^(&G_CONST_VAR_HORIZON_INDEX)$/i
								, ovar_variables = _data_keys)
	%&RSULogger.PutInfo(Join keys: &_join_keys.)
	%local /readonly _NO_OF_ELEMENTS_BEF = %&RSUDS.GetCount(%&DataObject.DSVariablePart(i_suffix = &i_data_id.));
	%local _join_key;
	%local _index_join_key;
	data %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(drop = _rc &_join_keys.);
		if (_N_ = 0) then do;
			set &_TARGET_DIM.(keep = &_data_keys.);
		end;
		set %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
		if (_N_ = 1) then do;
			declare hash hh_address(dataset: "&_TARGET_DIM");
	%do %while(%&RSUUtil.ForEach(i_items = &_join_keys.
										, ovar_item = _join_key
										, iovar_index = _index_join_key));
			_rc = hh_address.definekey("&_join_key.");
	%end;
			_rc = hh_address.definedata('address');
			_rc = hh_address.definedone();
		end;
		_rc = hh_address.find();
		if (_rc = 0) then do;
			output;
		end;
	run;
	quit;
	%local /readonly _NO_OF_ELEMENTS_AFT = %&RSUDS.GetCount(%&DataObject.DSVariablePart(i_suffix = &i_data_id.));
	%&RSULogger.PutInfo(# of element in data: &_NO_OF_ELEMENTS_BEF. >> &_NO_OF_ELEMENTS_AFT.)
	%if (&_NO_OF_ELEMENTS_BEF. ne &_NO_OF_ELEMENTS_AFT.) %then %do;
		%&RSUError.Throw(Incomaptible dimension)
		%return;
	%end;
%mend KVP__AssignAddress;

%macro KVP__CreateValueKey(i_data_id =
									, i_ref_function_name =
									, i_data_id_index =);
	%&RSULogger.PutNote(Creating value key of input data "&i_data_id.")
	%local /readonly _TMP_DS_VALUE_NAME_LIST = %&RSUDS.GetTempDSName(value_name_list);
	%&RSUDS.GetUniqueList(i_query = %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(keep = &G_CONST_VAR_VARIABLE_REF_NAME.)
								, i_by_variables = &G_CONST_VAR_VARIABLE_REF_NAME.
								, ods_output_ds = &_TMP_DS_VALUE_NAME_LIST.)
	data %DSVarMap(i_data_id = &i_data_id.);
		set &_TMP_DS_VALUE_NAME_LIST.;
		attrib
			variable_code length = $5.
			variable_ref length = $200.
		;
		variable_code = cats(put(&i_data_id_index., HEX2.), put(_N_ - 1, HEX3.));
		variable_ref = cats("&i_ref_function_name.{", &G_CONST_VAR_VARIABLE_REF_NAME., '}');
	run;
	quit;

	data %&DataObject.DSVariablePart(i_suffix = &i_data_id.)(drop = _rc &G_CONST_VAR_VARIABLE_REF_NAME. address variable_code);
		if (_N_ = 0) then do;
			set %DSVarMap(i_data_id = &i_data_id.)(drop = variable_ref);
		end;
		attrib
			value_key length = $20.
		;
		set %&DataObject.DSVariablePart(i_suffix = &i_data_id.);
		if (_N_ = 1) then do;
			declare hash hh_var_code(dataset: "%DSVarMap(i_data_id = &i_data_id.)");
			_rc = hh_var_code.definekey("&G_CONST_VAR_VARIABLE_REF_NAME.");
			_rc = hh_var_code.definedata('variable_code');
			_rc = hh_var_code.definedone();
		end;
		_rc = hh_var_code.find();
		value_key = catx(';', address, variable_code);
	run;
	quit;
%mend KVP__CreateValueKey;

%macro DSPrimaryKeyMap(i_primary_key =);
	&G_CONST_LIB_WORK..axis_&i_primary_key.
%mend DSPrimaryKeyMap;

%macro DSVarMap(i_data_id =);
	&G_CONST_LIB_WORK..var_&i_data_id.
%mend ;

%macro DSDim(i_name =);
	&G_CONST_LIB_WORK..dim_&i_name.
%mend DSDim;