/************************************************************************************************/
/* ValuePool.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/************************************************************************************************/
%RSUSetConstant(ValuePool, ValPool__)

/**===========================================**/
/* Formula計算の入力データを作成 & 解析用正規表現
/*
/* NOTE: 入力データはKey-Value Pair
/* NOTE: 必要なデータをすべて連結
/**===========================================**/
%macro ValPool__PrepareInput(i_formula_set_id =
									, ovar_regex_formula_parsing =
									, ovar_no_of_input_data =
									, ovar_regex_paramter_table =
									, ods_value_pool =);
	%&RSULogger.PutNote(Preparing input data for "&i_formula_set_id."...)
	%local _tmp_vpr_functions;
	%local _tmp_no_of_functions;
	%&VPRParser.FindVPRFunctions(i_formula_set_id = &i_formula_set_id.
										, i_extra_functions = &G_CONST_VPR_FUNC_SCENARIO. &G_CONST_VPR_FUNC_MODEL. &G_CONST_VPR_FUNC_TIME. &G_CONST_VPR_FUNC_REF.
										, ovar_vpr_functions = _tmp_vpr_functions
										, ovar_no_of_functions = &ovar_no_of_input_data.)
	%let &ovar_regex_formula_parsing. = %&VPRParser.CreateDecompRegex(i_functions = &_tmp_vpr_functions.
																							, i_regex_delimiter = &G_CONST_REGEX_VPR_FUNC_DELM.
																							, i_regex_argument = &G_CONST_REGEX_VPR_FUNC_ARGUMENT.);
	%let &ovar_regex_paramter_table = %&VPRParser.CreateDecompRegex(i_functions = &G_CONST_VPR_FUNC_PARAM_TABLE.
																						, i_regex_delimiter = &G_CONST_REGEX_VPR_FUNC_DELM.
																						, i_regex_argument = &G_CONST_REGEX_VPR_FUNC_ARGUMENT.);
	%CreateInputDataHelper(i_formula_set_id = &i_formula_set_id.
									, ods_value_pool = &ods_value_pool.)
%mend ValPool__PrepareInput;

%macro CreateInputDataHelper(i_formula_set_id =
									, ods_value_pool =);
	%&RSULogger.PutNote(Gathering input data for "&i_formula_set_id.")
	%local _data_id;
	%local _dsid_data_id;
	%local _input_data_info;
	%&RSUDS.Delete(&ods_value_pool.)
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_FORMULA_EVAL.(where = (formula_set_id = "&i_formula_set_id."))
										, i_vars = _data_id:data_id
										, ovar_dsid = _dsid_data_id));
		%&RSUDS.Concat(iods_base_ds = &ods_value_pool.
							, ids_data_ds = %&DataObject.DSVariablePart(i_suffix = &_data_id.))
		%let _no_of_obs = %&RSUDS.GetCount(%&DataObject.DSVariablePart(i_suffix = &_data_id.));
		%&RSUText.Append(iovar_base = _input_data_info
							, i_append_text = Data: &_data_id.(&_no_of_obs.)
							, i_delimiter = %str(,))
	%end;
	%&RSUDS.Concat(iods_base_ds = &ods_value_pool.
						, ids_data_ds = %&DataObject.DSVariablePart(i_suffix = &G_CONST_VPR_FUNC_TIME.))
	%&RSUDS.DropVariables(iods_dataset = &ods_value_pool.
								, i_variables = &G_CONST_VAR_TIME.)
	%&RSUError.Stop()
	%return;
	%let _no_of_obs = %&RSUDS.GetCount(%&DataObject.DSVariablePart(i_suffix = &G_CONST_VPR_FUNC_TIME.));
	%&RSUText.Append(iovar_base = _input_data_info
						, i_append_text = Data: &G_CONST_VPR_FUNC_TIME.(&_no_of_obs.)
						, i_delimiter = %str(,))
	%let _no_of_obs = %&RSUDS.GetCount(&ods_value_pool.);
	%&RSUText.Append(iovar_base = _input_data_info
						, i_append_text = Total: &_no_of_obs.
						, i_delimiter = %str(,))
	%&RSULogger.PutBlock([Normalized input data profile]
								, &_input_data_info.)
%mend CreateInputDataHelper;

/**=========================================**/
/* 新規計算結果を Key-Value pairに整形し連結
/**=========================================**/
%macro ValPool__CreateInputData(i_formula_set_id =
										, ids_result =
										, ids_formula_address =
										, ods_next_input_data =);
	data &ods_next_input_data.(keep = value value_key);
		if (_N_ = 0) then do;
			set &ids_result.;
		end;
		set &ids_formula_address.;
		if (_N_ = 1) then do;
			declare hash hh_result(dataset: "&ids_result.");
			__rc = hh_result.definekey('formula_index');
			__rc = hh_result.definedata('value');
			__rc = hh_result.definedone();
		end;
		attrib
			value_key length = $200.
		;
		__rc = hh_result.find();
		if (__rc = 0) then do;
			value_key = catx(';', address, &G_CONST_VAR_VARIABLE_REF_NAME.);
			output;
		end;
	run;
	quit;

	%&RSUDS.Append(iods_base_ds = %&DataObject.DSVariablePart(i_suffix = &i_formula_set_id.)
						, ids_data_ds = &ods_next_input_data.)
	%&RSULogger.PutInfo(Total # of evaluated value: %&RSUDS.GetCount(%&DataObject.DSVariablePart(i_suffix = &i_formula_set_id.)))
%mend ValPool__CreateInputData;
