/******************************************************/
/* AxisSpace.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/******************************************************/
%RSUSetConstant(AxisSpace, AxisSp__)

/**==============================**/
/* 空間軸を構成
/**==============================**/
%macro AxisSp__Compose(i_formula_set_id =
								, i_data_index =
								, ods_composite_axis =);
	%&RSULogger.PutNote(Combining space axies of formula "&i_formula_set_id.")

	%local /readonly _TMP_COMPOSIT_AXIS = %&RSUDS.GetTempDSName(composit_axis);
	%local _data_id;
	%local _data_index_in;
	%local _dsid_data_id;
	%local _ds_target_axis;
	%&RSUDS.Delete(&_TMP_COMPOSIT_AXIS. &ods_composite_axis.)
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_FORMULA_EVAL.(where = (formula_set_id = "&i_formula_set_id."))
										, i_vars = _data_id:data_id 
													_data_index_in:data_index_in
										, ovar_dsid = _dsid_data_id));
		%let _ds_target_axis = %DSAxis(i_data_index = &_data_index_in., i_axis_type = &G_CONST_VAR_ROLE_SPACE.);
		%if (%&RSUDS.Exists(&_ds_target_axis.)) %then %do;
			%&Axis.GatherAxis(i_data_id = &_data_id.
									, iods_gathered_layers = &_TMP_COMPOSIT_AXIS.
									, ids_layer_ds = &_ds_target_axis.)
		%end;
		%else %do;
			%&RSULogger.PutInfo(Data &_data_id. does not have space axis)
		%end;
	%end;
	%if (not %&RSUDS.Exists(&_TMP_COMPOSIT_AXIS.)) %then %do;
		%&RSULogger.PutInfo(No space layer)
		%return;
	%end;

	/* 新座標 */
	data &_TMP_COMPOSIT_AXIS.;
		attrib
			&G_CONST_VAR_COORDINATE_SPACE. length = $&G_CONST_COORDINATE_LEN_SPACE..
		;
		set &_TMP_COMPOSIT_AXIS.;
		&G_CONST_VAR_COORDINATE_SPACE. = put(_N_ - 1, HEX&G_CONST_COORDINATE_LEN_SPACE..);
	run;
	quit;

	/* 不要なFormula システムIDを取り除いて保存 */
	%local /readonly _FORMULA_SYSTEM_ID = %&RSUDS.GetValue(i_query = &G_SETTING_CONFIG_DS_FORMULA_EVAL.(where = (formula_set_id = "&i_formula_set_id." and not missing(formula_system_id_variable)))
																			, i_variable = formula_system_id_variable);
	%local /readonly _VARS_FORMULA_SYSTEM_ID = %&RSUDS.GetVariableArray(ids_dataset = &_TMP_COMPOSIT_AXIS.
																							, i_regex_include = /^formula_system_id/i
																							, i_regex_exclude = /^&_FORMULA_SYSTEM_ID./i);
	%&RSUDS.DropVariables(iods_dataset = &_TMP_COMPOSIT_AXIS.
								, i_variables = %&RSUArray.GetText(_VARS_FORMULA_SYSTEM_ID))
	%&RSUDS.Move(i_query = &_TMP_COMPOSIT_AXIS.(rename = &_FORMULA_SYSTEM_ID. = &G_CONST_VAR_FORM_SYSTEM_ID.)
					, ods_dest_ds = &ods_composite_axis.)
	%&RSUDS.Let(i_query = &ods_composite_axis.(drop = &G_CONST_VAR_COORDINATE.:)
					, ods_dest_ds = %DSAxis(i_data_index = &i_data_index., i_axis_type = &G_CONST_VAR_ROLE_SPACE.))
%mend AxisSp__Compose;
