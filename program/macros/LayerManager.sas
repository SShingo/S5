/******************************************************/
/* LayerManager.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: レイヤー構造の管理
/******************************************************/
%RSUSetConstant(LayerManager, LyrMgr__)

/**===============================**/
/* レイヤーコードを物理名に変換
/**===============================**/
%macro LyrMgr__Decode(iods_decode_map =
							, ids_coded_value =);
	%&RSULogger.PutNote(Decoding coded layer to physical layer...)
	%local /readonly _TMP_DS_CODED = %&RSUDS.GetTempDSName(coded_data);
	data &_TMP_DS_CODED.(drop = pos);
		set &ids_coded_value.;
		attrib
			address length = $20.
		;
		pos = find(value_key, ';', -length(value_key));
		address = substr(value_key, 1, pos - 1);
	run;
	quit;

	data &iods_decode_map.(drop = _rc address);
		if (_N_ = 0) then do;
			set &_TMP_DS_CODED.;
		end;
		set &iods_decode_map.;
		if (_N_ = 1) then do;
			declare hash hh_coded_result(dataset: "&_TMP_DS_CODED.", multidata: 'yes');
			_rc = hh_coded_result.definekey('address');
			_rc = hh_coded_result.definedata('value');
			_rc = hh_coded_result.definedata('value_key');
			_rc = hh_coded_result.definedone();
		end;
		_rc = hh_coded_result.find();
		if (_rc = 0) then do;
			output;
			_rc = hh_coded_result.find_next();
			do while(_rc = 0);
				output;
				_rc = hh_coded_result.find_next();
			end;
		end;
	run;
	quit;

	%&RSUDS.Delete(&_TMP_DS_CODED.)
%mend LyrMgr__Decode;

/**=================================**/
/* 各データのレイヤー構造
/**=================================**/
%macro LyrMgr__DSDataLayer(i_data_id =
									, i_layer_type =);
	%local /readonly _LAYER_ID_PREFIX = %LyrMgr__GetLayerPrefix(i_layer_type = &i_layer_type.);
	&G_CONST_LIB_WORK..&_LAYER_ID_PREFIX.&i_data_id.
%mend LyrMgr__DSDataLayer;

%macro LyrMgr__GetLayerPrefix(i_layer_type =);
	%local _layer_id_prefix;
	%if (&i_layer_type. = &G_CONST_VAR_ROLE_TIME.) %then %do;
		%let _layer_id_prefix = &G_CONST_LAYER_ID_TIME.;
	%end;
	%else %if (&i_layer_type. = &G_CONST_VAR_ROLE_SCENARIO.) %then %do;
		%let _layer_id_prefix = &G_CONST_LAYER_ID_SCENARIO.;
	%end;
	%else %if (&i_layer_type. = &G_CONST_VAR_ROLE_FORMULA_SYS_ID.) %then %do;
		%let _layer_id_prefix = &G_CONST_LAYER_ID_FORMULA_SYS_ID.;
	%end;
	%else %do;
		%let _layer_id_prefix = &G_CONST_LAYER_ID_SPACE.;
	%end;
	&_layer_id_prefix.
%mend LyrMgr__GetLayerPrefix;
