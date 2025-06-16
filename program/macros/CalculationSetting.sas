/****************************************************************************/
/* CalculatioSetting.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: 計算設定は1行データとして与えられる想定
/* NOTE: Stagingのみ
/* NOTE: transpose して縦型のデータセットにして保持（<result>/in/staging）
/* NOTE: 以降はこのデータセットの内容を参照する
/****************************************************************************/
%RSUSetConstant(CalculationSetting, CalcSetting__)
%RSUSetConstant(G_CONST_VAR_CALC_SETTING_KEY, key)
%RSUSetConstant(G_CONST_VAR_CALC_SETTING_VALUE, value)
%RSUSetConstant(G_CONST_VAR_CALC_SETTING_JOIN, setting_key)

/**======================================**/
/*	計算設定読み込み
/*
/* NOTE: データセット化
/* NOTE: キーとラベルの両方を保持しておく
/* NOTE: テーブル構造
/* NOTE: key | setting_key | value
/**======================================**/
%macro CalcSetting__Load(ovar_calc_settings_loaded =);
	%&RSULogger.PutSubsection(Process of calculation setting)
	%&RSULogger.PutNote(Importing calculation setting.)
	%local /readonly _TMP_DS_LOADED_CALC_SETTING = %&RSUDS.GetTempDSName();
	%&DataController.LoadExcel(i_excel_file_path = &G_DIR_USER_DATA_RSLT_DIR1_STG./&G_SETTING_CALC_SET_FILE_NAME.
										, i_setting_excel_file_path = &G_FILE_APPLICATION_CONFIG.
										, i_sheet_name = &G_SETTING_CALC_SET_SHEET_NAME.
										, ods_output_ds = &_TMP_DS_LOADED_CALC_SETTING.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error occured during loading excel file &G_DIR_USER_DATA_RSLT_DIR1_STG./&G_SETTING_CALC_SET_FILE_NAME.)
		%return;
	%end;
	proc transpose 
			data = &_TMP_DS_LOADED_CALC_SETTING. 
			out = &_TMP_DS_LOADED_CALC_SETTING._tr(rename = (_NAME_ = &G_CONST_VAR_CALC_SETTING_KEY. _LABEL_ = &G_CONST_VAR_VARIABLE_REF_NAME. COL1 = &G_CONST_VAR_VALUE.) keep = _NAME_ _LABEL_ COL1)
		;
		var
			_all_
		;
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_LOADED_CALC_SETTING.)

	data &_TMP_DS_LOADED_CALC_SETTING._tr;
		set &_TMP_DS_LOADED_CALC_SETTING._tr;
		&G_CONST_VAR_VARIABLE_REF_NAME. = cats('${', &G_CONST_VAR_VARIABLE_REF_NAME., '}');
		rename
			&G_CONST_VAR_VARIABLE_REF_NAME. = &G_CONST_VAR_CALC_SETTING_JOIN.
		;
	run;
	quit;
	%&Utility.ShowDSSingleColumn(ids_source_ds = &_TMP_DS_LOADED_CALC_SETTING._tr
										, i_variable_def = %quote(catx(' ', &G_CONST_VAR_CALC_SETTING_KEY., &G_CONST_VAR_CALC_SETTING_JOIN., &G_CONST_VAR_VALUE.))
										, i_title = [Calculation Settings])
	%&RSUDS.Move(i_query = &_TMP_DS_LOADED_CALC_SETTING._tr
					, ods_dest_ds = &G_CONST_DS_CALCULATION_SETTING.)
%mend CalcSetting__Load;

/**========================================**/
/* 計算設定値取得
/**========================================**/
%macro CalcSetting__Get(i_key =);
	%&RSUDS.GetValue(i_query = &G_CONST_DS_CALCULATION_SETTING.(where = (&G_CONST_VAR_CALC_SETTING_KEY. = "&i_key.")), i_variable = &G_CONST_VAR_VALUE.)
%mend CalcSetting__Get;

/**==============================**/
/* 計算設定値を代入
/**==============================**/
%macro CalcSetting__SubstituteValueTo(iods_formula_definition =
												, i_target_definition =);
	%&RSULogger.PutNote(Substututing calculation setting values into "&i_target_definition." in formula definition.)
	data &iods_formula_definition(drop = __tmp_decmp: __rc &G_CONST_VAR_CALC_SETTING_JOIN. &G_CONST_VAR_CALC_SETTING_VALUE. &G_CONST_VAR_CALC_SETTING_KEY.);
		if (_N_ = 0) then do;
			set 
				&G_CONST_DS_CALCULATION_SETTING.
			;
		end;
		set &iods_formula_definition. end = eof;
		attrib
			__tmp_decmp_expression_replaced length = $3000.
			__tmp_decmp_definition length = $3000.
		;
		if (_N_ = 1) then do;
			declare hash hh_value(dataset: "&G_CONST_DS_CALCULATION_SETTING.");
			__rc = hh_value.definekey("&G_CONST_VAR_CALC_SETTING_JOIN.");
			__rc = hh_value.definedata("&G_CONST_VAR_CALC_SETTING_VALUE.");
			__rc = hh_value.definedone();
		end;
		__tmp_decmp_regex_formula_ref = prxparse("/&G_CONST_REGEX_CALC_SETTING_DELM.(&G_CONST_REGEX_CALC_SETTING.)/o");
		__tmp_decmp_definition = cat('`', strip(&i_target_definition.), '`');
		__tmp_decmp_org_length = lengthn(__tmp_decmp_definition);
		__tmp_decmp_start = 1;
		__tmp_decmp_stop = __tmp_decmp_org_length;
		__tmp_decmp_position = 0;
		__tmp_decmp_length = 0;
		__tmp_decmp_prev_start = 1;
		__tmp_decmp_finished = 0;
		__tmp_decmp_safty_index = 0;
		__tmp_decmp_expression_replaced = '';
		do while(__tmp_decmp_safty_index < 100);
			call prxnext(__tmp_decmp_regex_formula_ref, __tmp_decmp_start, __tmp_decmp_stop, __tmp_decmp_definition, __tmp_decmp_position, __tmp_decmp_length);
			if (__tmp_decmp_position = 0) then do;
				__tmp_decmp_finished = 1;
				__tmp_decmp_position = __tmp_decmp_org_length; 
			end;
			__tmp_decmp_expression_replaced = catt(__tmp_decmp_expression_replaced, cat('`', substr(__tmp_decmp_definition, __tmp_decmp_prev_start, __tmp_decmp_position - __tmp_decmp_prev_start + 1), '`'));
			if (__tmp_decmp_finished = 1) then do;
				leave;
			end;
			&G_CONST_VAR_CALC_SETTING_JOIN. = prxposn(__tmp_decmp_regex_formula_ref, 1, __tmp_decmp_definition);
			__rc = hh_value.find();
			if (__rc = 0) then do;
				__tmp_decmp_expression_replaced = catt(__tmp_decmp_expression_replaced, &G_CONST_VAR_CALC_SETTING_VALUE.);			
			end;
			else do;
				__tmp_decmp_expression_replaced = catt(__tmp_decmp_expression_replaced, &G_CONST_VAR_CALC_SETTING_JOIN.);			
			end;
			__tmp_decmp_prev_start = __tmp_decmp_position + __tmp_decmp_length;
			__tmp_decmp_safty_index = __tmp_decmp_safty_index + 1;
		end;
		&i_target_definition. = compress(__tmp_decmp_expression_replaced, '`');
		output;
	run;
	quit;
%mend CalcSetting__SubstituteValueTo;
