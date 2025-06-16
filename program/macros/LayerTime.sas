/******************************************************/
/* LayerTime.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: レイヤー時間成分
/* NOTE: レイヤーID ⇔ 実値
/******************************************************/
%RSUSetConstant(LayerTime, LyrTi__)

/**===================================================**/
/* 時間レイヤー作成
/**===================================================**/
%macro LyrTi__Create(ids_source_ds =
							, i_data_id =);
	%local /readonly _TARGET_LAYER_DS = %&LayerManager.DSDataLayer(i_data_id = &i_data_id., i_layer_type = &G_CONST_VAR_ROLE_TIME.);
	%&RSULogger.PutNote(Create time layer of "&i_data_id." (&_TARGET_LAYER_DS.))
	%&RSUDS.Delete(&_TARGET_LAYER_DS.)
	%local /readonly _VARS_OF_LAYER = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&i_data_id."))
																		, i_variable = &G_CONST_VAR_ROLE_TIME.);
	%if (%&RSUUtil.IsMacroBlank(_VARS_OF_LAYER)) %then %do;
		%&RSULogger.PutInfo(No variables with "&G_CONST_VAR_ROLE_TIME." role found in &i_data_id.)
		%return;
	%end;
	proc sort data = &ids_source_ds.(keep = &_VARS_OF_LAYER.) out = WORK.tmp_layers nodupkey;
		by
			&_VARS_OF_LAYER.
		;
	run;
	quit;
	data WORK.tmp_layers;
		attrib
			coordinate length = 8.
		;
		set WORK.tmp_layers;
		coordinate = &_VARS_OF_LAYER.;
	run;
	quit;	
	%&RSUDS.Move(i_query = WORK.tmp_layers
					, ods_dest_ds = &_TARGET_LAYER_DS.)
%mend LyrTi__Create;

/**===================================================**/
/* 時間レイヤー作成
/**===================================================**/
%macro LyrTi__Encode(iods_source_ds =);
	%&RSULogger.PutNote(Assigning layer-id to variable with "&G_CONST_VAR_ROLE_TIME.")
	%local /readonly _TIME_VAR = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&i_data_id."))
																, i_variable = &G_CONST_VAR_ROLE_TIME.);
	%if (not %&RSUUtil.IsMacroBlank(_TIME_VAR)) %then %do;
		data &iods_source_ds.;
			set &iods_source_ds.;
			coordinate_&G_CONST_VAR_ROLE_TIME. = &_TIME_VAR.;
		run;
	%end;
%mend LyrTi__Encode;

/*---------------------------------*/
/* 時間成分 レイヤーを構成
/*---------------------------------*/
%macro LyrTi__Compose(i_formula_set_id =
|							, i_horizon_end =
							, ods_composite_layer =);
	%&RSULogger.PutNote(Generating time axes of formula "&i_formula_set_id.")

	%local _data_index;
	%local _dsid_data_id;
	%do %while(%&RSUDS.ForEaxh(i_query = &G_SETTING_CONFIG_DS_FORMULA_EVAL.(where = (formula_set_id = "&i_formula_set_id."))
										, i_vars = _data_index:data_index
										, ovar_dsid = _dsid_data_id));
		%&LayerComposer.GatherAxis(iods_gathered_layers = &_TMP_COMPOSED_LAYER.
											, ids_layer_ds = %&DSAxis(i_data_index = &_data_index., i_axis_type = &G_CONST_VAR_ROLE_TIME.);
	%end;
	%&RSUDS.Move(i_query = &_TMP_COMPOSED_LAYER.
					, ods_dest_ds = &ods_composite_layer.)

	/* 新座標 */
	data %&Axis.DSAxis(i_data_index = &i_formula_set_index., i_axis_type = &G_CONST_VAR_ROLE_TIME.);
		attrib
			&G_CONST_VAR_COORDINATE_TIME. length = $&G_CONST_COORDINATE_LEN_TIME..
		;
		set &ods_composite_layer.(drop = &G_CONST_VAR_COORDINATE.:);
		&G_CONST_VAR_COORDINATE_TIME = put(_N_ - 1, HEX$&G_CONST_COORDINATE_LEN_TIME..);
	run;
	quit;%mend LyrTi__Compose;