/******************************************************/
/* LayerCoder.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: レイヤーID ⇔ 実値
/******************************************************/
%RSUSetConstant(LayerCoder, LyrCoder__)

/**======================================**/
/* 実分類データ→レイヤーID
/**======================================**/
%macro LyrCoder__Encode(iods_source_ds =
								, i_variables_in_layer =
								, ids_layer =
								, i_layer_type =);
	%&RSULogger.PutInfo(Layer variable(s) in &ids_layer.: %quote(&i_variables_in_layer.))
	%local _variable;
	%local _index_variable;
	data &iods_source_ds.(drop = _rc);
		if (_N_ = 0) then do;
			set &ids_layer.;
		end;
		set &iods_source_ds.;
		if (_N_ = 1) then do;
			declare hash hh_elements(dataset: "&ids_layer.");
	%do %while(%&RSUUtil.ForEach(i_items = &i_variables_in_layer.
										, ovar_item = _variable
										, iovar_index = _index_variable));
			_rc = hh_elements.definekey("&_variable.");
	%end;
			_rc = hh_elements.definedata("coordinate");
			_rc = hh_elements.definedone();
		end;
		_rc = hh_elements.find();
		rename
			coordinate = coordinate_&i_layer_type.
		;
	run;
	quit;
%mend LyrCoder__Encode;

/**======================================**/
/* レイヤーID→実分類データ
/**======================================**/
%macro LyrCoder__Decode(iods_data =
								, i_formula_id =
								, i_variable_role =);
	%&RSULogger.PutNote(Decoding layer-id(&i_variable_role.) to actual elements...)
	%if (%&RSUDS.IsDSEmpty(&G_CONST_DS_LAYER_STRUCT_DATA.(where = (formula_id = "&i_formula_id." and not missing(join_layer_&i_variable_role.))))) %then %do;
		%&RSULogger.PutInfo(No "&i_variable_role." layer in formula "&i_formula_id.")
		%return;
	%end;
	%local _data_id;
	%local _join_layer;
	%local _dsid_data_id;
	%do %while(%&RSUDS.ForEach(i_query = &G_CONST_DS_LAYER_STRUCT_DATA.(where = (formula_id = "&i_formula_id." and not missing(join_layer_&i_variable_role.)))
											, i_vars = _data_id:data_id
															_join_layer:join_layer_&i_variable_role.
											, ovar_dsid = _dsid_data_id));
		%&RSUDS.InnerJoin(ids_lhs_ds = &iods_data.
								, ids_rhs_ds = %&LayerManager.DSDataLayer(i_data_id = &_data_id, i_layer_type = &i_variable_role.)
								, i_conditions = &_join_layer.:&_join_layer.)
		%&RSUDS.DropVariables(iods_dataset = &iods_data.
									, i_variables = &_join_layer.)
	%end;
%mend LyrCoder__Decode;


