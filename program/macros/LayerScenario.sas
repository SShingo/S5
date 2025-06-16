/******************************************************/
/* LayerScenario.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: レイヤーシナリオ成分
/* NOTE: レイヤーID ⇔ 実値
/******************************************************/
%RSUSetConstant(LayerScenario, LyrSc__)

/**===================================**/
/* レイヤー作成
/**===================================**/
%macro LyrSc__Create(ids_source_ds =
							, i_data_id =);
	%local /readonly _TARGET_LAYER_DS = %&LayerManager.DSDataLayer(i_data_id = &i_data_id., i_layer_type = &G_CONST_VAR_ROLE_SCENARIO.);
	%&RSULogger.PutNote(Create scenario layer of "&i_data_id." (&_TARGET_LAYER_DS.))
	%&RSUDS.Delete(&_TARGET_LAYER_DS.)
	%local /readonly _VARS_OF_LAYER = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&i_data_id."))
																		, i_variable = &G_CONST_VAR_ROLE_SCENARIO.);
	%if (%&RSUUtil.IsMacroBlank(_VARS_OF_LAYER)) %then %do;
		%&RSULogger.PutInfo(No variables with "&G_CONST_VAR_ROLE_SCENARIO." role found in &i_data_id.)
		%return;
	%end;
	%&RSUDS.GetUniqueList(i_query = &ids_source_ds.(drop = &G_CONST_VAR_VALUE.)
								, i_by_variables = &_VARS_OF_LAYER.
								, ods_output_ds = &_TARGET_LAYER_DS.)
	data &_TARGET_LAYER_DS.(keep = &_VARS_OF_LAYER. coordinate);
		attrib
			coordinate length = 8.
		;
		set &_TARGET_LAYER_DS.;
		coordinate = _N_;
	run;
	quit;
	%local /readonly _NO_OF_ELEMENTS_IN_LAYER = %&RSUDS.GetCount(&_TARGET_LAYER_DS.);
	%&RSULogger.PutInfo(# of elements in scenario layer: &_NO_OF_ELEMENTS_IN_LAYER.)
%mend LyrSc__Create;

/**==============================================**/
/* シナリオレイヤー付与
/**==============================================**/
%macro LyrSc__Encode(iods_source_ds =
							, i_data_id =);
	%&RSULogger.PutNote(Assigning layer-id to variable with "&G_CONST_VAR_ROLE_SCENARIO." role)
	%local /readonly _DS_LAYER = %&LayerManager.DSDataLayer(i_data_id = &i_data_id., i_layer_type = &G_CONST_VAR_ROLE_SCENARIO.);
	%local /readonly _VARS_OF_LAYER = %&RSUDS.GetValue(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (data_id = "&i_data_id."))
																		, i_variable = &G_CONST_VAR_ROLE_SCENARIO.);
	%&LayerCoder.Encode(iods_source_ds = &iods_source_ds.
							, i_variables_in_layer = &_VARS_OF_LAYER.
							, ids_layer = &_DS_LAYER.
							, i_layer_type = &G_CONST_VAR_ROLE_SCENARIO.)
%mend LyrSc__Encode;
