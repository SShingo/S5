/******************************************************/
/* Variable.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/******************************************************/
%RSUSetConstant(VariableEncoder, VarEnc__);
%RSUSetConstant(G_CONST_VAR_VARIABLE_CODE, variable_code)
%RSUSetConstant(G_CONST_VAR_VARIABLE_CODE_LEN, 5)

%macro VarEnc__Encode(i_data_id =
							, i_data_index =
							, i_variable_variable_name =
							, iods_source_ds =);
	%local /readonly _DS_VARIABLE_LIST = %DSVarList(i_data_index = &i_data_index.);
	%&RSULogger.PutNote(Encoding variables in &iods_source_ds.)
	%&RSUDS.GetUniqueList(i_query = &iods_source_ds.(keep = &i_variable_variable_name.)
								, i_by_variables = &i_variable_variable_name.
								, ods_output_ds = &_DS_VARIABLE_LIST.)
	data &_DS_VARIABLE_LIST.;
		attrib
			&G_CONST_VAR_VARIABLE_CODE. length = $&G_CONST_VAR_VARIABLE_CODE_LEN..
		;
		set &_DS_VARIABLE_LIST.;
		&G_CONST_VAR_VARIABLE_CODE. = cats("&i_data_index.", put(_N_ - 1, HEX3.));
	run;
	quit;
	%&RSUDS.SetLabel(iods_target_ds = &_DS_VARIABLE_LIST.
						, i_label = &i_data_id.)			

	data &iods_source_ds.(drop = _rc &i_variable_variable_name.);
		if (_N_ = 0) then do;
			set &_DS_VARIABLE_LIST.;
		end;
		set &iods_source_ds.;
		if (_N_ = 1) then do;
			declare hash hh_var_list(dataset: "&_DS_VARIABLE_LIST.");
			_rc = hh_var_list.definekey("&i_variable_variable_name.");
			_rc = hh_var_list.definedata("&G_CONST_VAR_VARIABLE_CODE.");
			_rc = hh_var_list.definedone();
		end;
		_rc = hh_var_list.find();
	run;
	quit;
%mend VarEnc__Encode;

%macro VarEnc__EncodeRefVariable(ids_vairable_list =);
	%local /readonly _TMP_DS_DATA_ID_LIST = %&RSUDS.GetTempDSName(data_id_list);
	%&RSUDS.GetUniqueList(i_query = &ids_vairable_list.(keep = data_id)
								, i_by_variables = data_id
								, ods_output_ds = &_TMP_DS_DATA_ID_LIST.)
	%local /readonly _NO_OF_DATA_INDEX_OFFSET = %&RSUDS.GetCount(&G_CONST_DS_EXTERNAL_DATA_LIST.);
	data &_TMP_DS_DATA_ID_LIST.;
		set &_TMP_DS_DATA_ID_LIST.;
		attrib
			ref_function_name length = $30.
			data_index length = $2.
		;
		ref_function_name = "&G_CONST_VPR_FUNC_REF.";
		data_index = put(_N_ + &_NO_OF_DATA_INDEX_OFFSET., HEX2.);
	run;
	quit;

	%&RSUDS.Concat(iods_base_ds = &G_CONST_DS_EXTERNAL_DATA_LIST.
						, ids_data_ds = &_TMP_DS_DATA_ID_LIST.)
	%&RSUDS.Delete(&_TMP_DS_DATA_ID_LIST.)

	%local _data_id;
	%local _data_index;
	%local _dsid_data_id;
	%local /readonly _TMP_DS_VARIABLES_IN_DATA_ID = %&RSUDS.GetTempDSName(variable_in_data_id);
	%do %while(%&RSUDS.ForEach(i_query = &G_CONST_DS_EXTERNAL_DATA_LIST.(where = (ref_function_name = "&G_CONST_VPR_FUNC_REF."))
										, i_vars = _data_id:data_id
													_data_index:data_index
										, ovar_dsid = _dsid_data_id));
		%&RSUDS.Let(i_query = &ids_vairable_list.(where = (data_id = "&_data_id."))
						, ods_dest_ds = &_TMP_DS_VARIABLES_IN_DATA_ID.)
		%&VariableEncoder.Encode(i_data_id = &_data_id.
										, i_data_index = &_data_index.
										, i_variable_variable_name = &G_CONST_VAR_VARIABLE_REF_NAME.
										, iods_source_ds = &_TMP_DS_VARIABLES_IN_DATA_ID.)
		%&RSUDS.Delete(&_TMP_DS_VARIABLES_IN_DATA_ID.)
	%end;
%mend VarEnc__EncodeRefVariable;

%macro DSVarList(i_data_index =);
	&G_CONST_LIB_WORK..variable_code_&i_data_index.
%mend DSVarList;