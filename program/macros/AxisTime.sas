/******************************************************/
/* AxisTime.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/******************************************************/
%RSUSetConstant(AxisTime, AxisTi__)

/**==================================**/
/* 時間軸を構成
/**==================================**/
%macro AxisTi__Compose(i_formula_set_id =
							, i_data_index =
							, i_horizon_end =
							, ods_composite_axis =);
	%&RSULogger.PutNote(Combining space axies of formula  "&i_formula_set_id.")

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
		%let _ds_target_axis = %DSAxis(i_data_index = &_data_index_in., i_axis_type = &G_CONST_VAR_ROLE_TIME.);
		%if (%&RSUDS.Exists(&_ds_target_axis.)) %then %do;
			%&Axis.GatherAxis(i_data_id = &_data_id.
									, iods_gathered_layers = &_TMP_COMPOSIT_AXIS.
									, ids_layer_ds = &_ds_target_axis.)
		%end;
		%else %do;
			%&RSULogger.PutInfo(Data &_data_id. does not have time axis)
		%end;
	%end;
	%if (not %&RSUDS.Exists(&_TMP_COMPOSIT_AXIS.)) %then %do;
		%&RSULogger.PutInfo(No time layer)
		%return;
	%end;

	/* 新座標 */
	data &_TMP_COMPOSIT_AXIS.;
		attrib
			&G_CONST_VAR_COORDINATE_TIME. length = $&G_CONST_COORDINATE_LEN_TIME..
		;
		set &_TMP_COMPOSIT_AXIS.;
		&G_CONST_VAR_COORDINATE_TIME = put(_N_ - 1, HEX&G_CONST_COORDINATE_LEN_TIME..);
	run;
	quit;

	%&RSUDS.Move(i_query = &_TMP_COMPOSIT_AXIS.
					, ods_dest_ds = &ods_composite_axis.)
	%&RSUDS.Let(i_query = &ods_composite_axis.(drop = &G_CONST_VAR_COORDINATE.:)
					, ods_dest_ds = %DSAxis(i_data_index = &i_data_index., i_axis_type = &G_CONST_VAR_ROLE_TIME.))
%mend AxisTi__Compose;