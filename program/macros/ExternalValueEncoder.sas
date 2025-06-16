/***************************************************/
/* ExternalValueEncoder.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***************************************************/
%RSUSetConstant(ExternalValueEncoder, ExtValEnc__)

/*---------------------------------------*/
/* 入力データを Key-Value pair に変更
/*---------------------------------------*/
%macro ExtValEnc__MakeKVP();
	%&RSULogger.PutSubsection(Key-Value pair conversion)
	%local _data_id;
	%local _dsid_data_id;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_LOADING_DATA.
										, i_vars = _data_id:data_id
										, ovar_dsid = _dsid_data_id));
		%DefineVariable(i_data_id = &_data_id.
							, iods_input_ds = %&DataObject.DSVariablePart(i_suffix = &_data_id.))
	%end;
	%&TimeAxis.CreateCommonTimeAxis()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to create time axis)
		%return;
	%end;

	/* KVP化 */
	%local _data_id;
	%local _data_index;
	%local _ref_function_name;
	%local _dsid_data_id;
	%local /readonly _TMP_DS_AXIS_SPACE = %&RSUDS.GetTempDSName(axis_space);
	%local /readonly _TMP_DS_AXIS_SCENARIO = %&RSUDS.GetTempDSName(axis_scenario);
	%local /readonly _TMP_DS_AXIS_TIME = %&RSUDS.GetTempDSName(axis_time);
	%local _ds_target_data;

	%do %while(%&RSUDS.ForEach(i_query = &G_CONST_DS_EXTERNAL_DATA_LIST.
										, i_vars = _data_id:data_id
													_data_index:data_index
													_ref_function_name:ref_function_name
										, ovar_dsid = _dsid_data_id));
		%let _ds_target_data = %&DataObject.DSVariablePart(i_suffix = &_data_id.);
		data &_ds_target_data.;
			set &_ds_target_data.;
			&G_CONST_VAR_VARIABLE_REF_NAME. = cats("&_ref_function_name.{", &G_CONST_VAR_VARIABLE_REF_NAME., '}');
		run;
		quit;
		%&Axis.CreateAxis(i_data_id = &_data_id. 
								, i_data_index = &_data_index.
								, ids_source_ds = &_ds_target_data.) 
		%&VariableEncoder.Encode(i_data_id = &_data_id.
										, i_data_index = &_data_index
										, i_variable_variable_name = &G_CONST_VAR_VARIABLE_REF_NAME.
										, iods_source_ds = &_ds_target_data.)
		%&KVP.Create(i_data_id = &_data_id.
						, i_data_index = &_data_index
						, iods_source_ds = &_ds_target_data.)
	%end;
%mend ExtValEnc__MakeKVP;

%macro DefineVariable(i_data_id =
							, iods_input_ds =);
	%&RSULogger.PutNote(Defining variables in "&i_data_id."...)
	%local _variable_name;
	%local _variable_definition;
	%local _variable_role;
	%local _is_primary_key;
	%local _time_range;
	%local _dsid_variable_name;
	%local _var_name_code_space;
	%local _var_name_code_scenario;
	%local _var_name_code_time;
	%local _var_name_code_form_sys_id;
	%local _var_name_code_value;
	%local _var_attr_code_space;
	%local _var_attr_code_scenario;
	%local _var_attr_code_time;
	%local _var_attr_code_form_sys_id;
	%local _var_attr_code_value;
	%local _var_def_code_space;
	%local _var_def_code_scenario;
	%local _var_def_code_time;
	%local _var_def_code_form_sys_id;
	%local _var_def_code_value;

	%local _appl_time_range;
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_VAR_DEF.(where = (data_id = "&i_data_id."))
										, i_vars = _variable_name:variable_name
													_variable_definition:variable_definition
													_variable_role:variable_role
													_time_range:time_range
										, ovar_dsid = _dsid_variable_name));
		%let _define_code = &_variable_definition.;
		%let _define_code = cats(%sysfunc(tranwrd(&_define_code., %nrstr(&), %str(,))));
		%if (&_variable_role. = &G_CONST_VAR_ROLE_SPACE.) %then %do;
			%DefineCodeHelper(i_var_role = &G_CONST_VAR_ROLE_SPACE.
									, i_variable_name = &_variable_name.
									, i_variable_length = $200.
									, i_variable_definition = &_define_code.
									, ovar_var_name_code = _var_name_code_space
									, ovar_var_attr_code = _var_attr_code_space
									, ovar_var_def_code = _var_def_code_space)
		%end;
		%else %if (&_variable_role. = &G_CONST_VAR_ROLE_SCENARIO.) %then %do;
			%DefineCodeHelper(i_var_role = &G_CONST_VAR_ROLE_SCENARIO.
									, i_variable_name = &_variable_name.
									, i_variable_length = $100.
									, i_variable_definition = &_define_code.
									, ovar_var_name_code = _var_name_code_scenario
									, ovar_var_attr_code = _var_attr_code_scenario
									, ovar_var_def_code = _var_def_code_scenario)
		%end;
		%else %if (&_variable_role. = &G_CONST_VAR_ROLE_TIME.) %then %do;
			%DefineCodeHelper(i_var_role = &G_CONST_VAR_ROLE_TIME.
									, i_variable_name = &_variable_name.
									, i_variable_length = $8.
									, i_variable_definition = &_define_code.
									, ovar_var_name_code = _var_name_code_time
									, ovar_var_attr_code = _var_attr_code_time
									, ovar_var_def_code = _var_def_code_time)
			%let _appl_time_range = &_time_range.;
		%end;
		%else %if (&_variable_role. = &G_CONST_VAR_ROLE_FORMULA_SYS_ID.) %then %do;
			%DefineCodeHelper(i_var_role = &G_CONST_VAR_ROLE_FORMULA_SYS_ID.
									, i_variable_name = &_variable_name.
									, i_variable_length = $32.
									, i_variable_definition = &_define_code.
									, ovar_var_name_code = _var_name_code_form_sys_id
									, ovar_var_attr_code = _var_attr_code_form_sys_id
									, ovar_var_def_code = _var_def_code_form_sys_id)
		%end;
		%else %do;
			%DefineCodeHelper(i_var_role = Value
									, i_variable_name = &_variable_name.
									, i_variable_length = $200.
									, i_variable_definition = &_define_code.
									, ovar_var_name_code = _var_name_code_value
									, ovar_var_attr_code = _var_attr_code_value
									, ovar_var_def_code = _var_def_code_value)
		%end;
	%end;

	%local /readonly _TMP_DS_SOURCE = %&RSUDS.GetTempDSName(source);
	data &iods_input_ds.;
		attrib
			&_var_attr_code_space.
			&_var_attr_code_scenario.
			&_var_attr_code_time.
			&_var_attr_code_form_sys_id.
			&_var_attr_code_value.
		;
		set &iods_input_ds.(rename = COL1 = &G_CONST_VAR_VALUE.);
		&_var_def_code_space.
		&_var_def_code_form_sys_id.
		&_var_def_code_scenario.
		&_var_def_code_time.
		&_var_def_code_value.
		keep
			&_var_name_code_space.
			&_var_name_code_form_sys_id.
			&_var_name_code_scenario.
			&_var_name_code_time.
			&_var_name_code_value.
			&G_CONST_VAR_VALUE.
		;
	run;
	quit;
%mend DefineVariable;

%macro DefineCodeHelper(i_var_role =
								, i_variable_name =
								, i_variable_length =
								, i_variable_definition =
								, ovar_var_name_code =
								, ovar_var_attr_code =
								, ovar_var_def_code =);
	%&RSULogger.PutInfo(Variable definition(Role: &i_var_role.): &i_variable_name. = &i_variable_definition.)
	%&RSUText.Append(iovar_base = &ovar_var_name_code.
						, i_append_text = &i_variable_name.)
	%&RSUText.Append(iovar_base = &ovar_var_attr_code.
						, i_append_text = &i_variable_name. length = &i_variable_length.)
	%&RSUText.Append(iovar_base = &ovar_var_def_code.
						, i_append_text = &i_variable_name. = &i_variable_definition.;)
%mend DefineCodeHelper;
