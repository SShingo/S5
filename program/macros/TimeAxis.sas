/***************************************************/
/* TimeAxis.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***************************************************/
%RSUSetConstant(TimeAxis, TimeAxis__)

/**========================================================**/
/* 共通時間軸データ作成
/*
/* NOTE: Newton力学の概念を採用。時間軸のCoordinateを世界で一つにするために共通時間軸を作成 */
/* NOTE: 時間成分を持っているすべてのExernal Dataの和集合
/**========================================================**/
%macro TimeAxis__CreateCommonTimeAxis();
	%&RSULogger.PutSubsection(Common Time Axis)
	%local _data_id;
	%local _time_range;
	%local _dsid_data_id;
	%local /readonly _TMP_TIME_ALL = %&RSUDS.GetTempDSName(time_all);
	%local /readonly _HORIZON_AS_OF = %&CalculationSetting.Get(i_key = horizon_as_of);
	%do %while(%&RSUDS.ForEach(i_query = &G_SETTING_CONFIG_DS_VAR_DEF.(where = (variable_role = "&G_CONST_VAR_ROLE_TIME." and data_id ne "&G_CONST_VPR_FUNC_TIME."))
										, i_vars = _data_id:data_id
													_time_range:time_range
										, ovar_dsid = _dsid_data_id));
		%&RSULogger.PutNote(Gathering time information in &_data_id.)
		%if (not %&RSUUtil.IsMacroBlank(_time_range)) %then %do;
			%LimitTimeRange(iods_input_ds = %&DataObject.DSVariablePart(i_suffix = &_data_id.)
								, i_time_range = &_time_range.
								, i_time_variable = &G_CONST_VAR_TIME.
								, i_horizon_as_of = &_HORIZON_AS_OF.)
			%if (%&RSUError.Catch()) %then %do;
				%&RSUError.Throw(Failed to define variable)
				%&RSUDS.TerminateLoop(_dsid_data_id)
				%return;
			%end;
		%end;
		%&RSUDS.Append(iods_base_ds = &_TMP_TIME_ALL.
							, ids_data_ds = %&DataObject.DSVariablePart(i_suffix = &_data_id.)(keep = &G_CONST_VAR_TIME.))
	%end;

	%CreateCommonTimeAxisHelper(ids_time_source = &_TMP_TIME_ALL.
										, i_horizon_as_of = &_HORIZON_AS_OF.)
	%&RSUDS.Delete(&_TMP_TIME_ALL.)
%mend TimeAxis__CreateCommonTimeAxis; 

%macro CreateCommonTimeAxisHelper(ids_time_source =
											, i_horizon_as_of =);
	%local /readonly _TMP_DS_TIME_AXIS = %&RSUDS.GetTempDSName(time_axis);	
	%&RSUDS.GetUniqueList(i_query = &ids_time_source.
								, i_by_variables = &G_CONST_VAR_TIME.
								, ods_output_ds = &_TMP_DS_TIME_AXIS.)
	%local _horizon_index_as_of;
	data &_TMP_DS_TIME_AXIS.;
		set &_TMP_DS_TIME_AXIS.;
		attrib
			__horizon__ length = $8. label = "&G_SETTING_TIME_VARIABLE_NAME.";
		;
		__horizon__ = &G_CONST_VAR_TIME.;
		if (&G_CONST_VAR_TIME. = &i_horizon_as_of.) then do;
			call symputx('_horizon_index_as_of', _N_);
		end;
	run;
	quit;

	%local _min_horizon;
	%local _min_horizon_index;
	%local _max_horizon;
	%local _max_horizon_index;
	data &_TMP_DS_TIME_AXIS.;
		set &_TMP_DS_TIME_AXIS. end = eof;
		attrib
			__horizon_index__ length = 8. label = "&G_SETTING_TIME_IDX_VARIABLE_NAME.";
		;
		__horizon_index__ = _N_ - &_horizon_index_as_of.;
		if (_N_ = 1) then do;
			call symputx('_min_horizon', &G_CONST_VAR_TIME.);
			call symputx('_min_horizon_index', __horizon_index__);
		end;
		if (eof) then do;
			call symputx('_max_horizon', &G_CONST_VAR_TIME.);
			call symputx('_max_horizon_index', __horizon_index__);
		end;
	run;
	quit;
	proc transpose data = &_TMP_DS_TIME_AXIS. out = %&DataObject.DSVariablePart(i_suffix = &G_CONST_VPR_FUNC_TIME.);
		by
			&G_CONST_VAR_TIME.
		;
		var
			__horizon__
			__horizon_index__
		;
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_TIME_AXIS.)
	data %&DataObject.DSVariablePart(i_suffix = &G_CONST_VPR_FUNC_TIME.)(keep = &G_CONST_VAR_TIME. &G_CONST_VAR_VARIABLE_REF_NAME. &G_CONST_VAR_VALUE.);
		attrib
			&G_CONST_VAR_VARIABLE_REF_NAME. length = $200.
			&G_CONST_VAR_VALUE. length = $100.
		;
		set %&DataObject.DSVariablePart(i_suffix = &G_CONST_VPR_FUNC_TIME.);
		&G_CONST_VAR_VARIABLE_REF_NAME. = _LABEL_;
		&G_CONST_VAR_VALUE. = compress(COL1);
	run;
	quit;
	%if (&_min_horizon_index. < 0) %then %do;
		%&RSULogger.PutBlock([Common Time Axis]
								, &_min_horizon.(&_min_horizon_index.) - &i_horizon_as_of.(0) - &_max_horizon.(&_max_horizon_index.))
	%end;
	%else %do;
		%&RSULogger.PutBlock([Common Time Axis]
								, &_horizon_index_as_of.(0) - &_max_horizon.(&_max_horizon_index.))
	%end;
%mend CreateCommonTimeAxisHelper;
