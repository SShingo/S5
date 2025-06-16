/******************************************************/
/* ScenarioManager.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/******************************************************/
%RSUSetConstant(ScenarioManager, ScnMgr__)

/**=================================================================**/
/* シナリオデータセット作成
/*
/* NOTE: Risk Scenario Manager < Predefined < Stagingの順
/* NOTE: "Scenario"という data_idを付与して ValuePoolとして保持
/**=================================================================**/
%macro ScnMgr__CreateDSFromRSM(ids_scenario_setting = 
										, i_fa_id =
										, i_host =
										, i_port =
										, i_ticket =
										, i_user_id =
										, i_password =);
	%&RSULogger.PutSubsection(Scenario data in SAS(R) Risk Scenario Manager)
	%&RSULogger.PutBlock([RSM credential info]
								, Federated area id: &i_fa_id.
								, Host: &i_host.:&i_port.
								, TGT ticket: &i_ticket.
								, UserId/Password: &i_user_id.(&i_password.))
	%SASIRMSetupHelper(i_fa_id = &i_fa_id.)

	/* RSMに登録されているシナリオリスト */
	%GenerateScenarioListInRSM(i_host = &i_host.
										, i_port = &i_port.
										, i_tgt_ticket = &i_tgt_ticket.
										, i_user_id = &i_user_id.
										, i_password = &i_password.
										, ods_scenario_list = WORK.tmp_scenarios_in_rsm)

	/* 指定シナリオのうち、RSMに存在するものをValuePoolとして保存 */
	%&RSUDS.LeftJoin(ids_lhs_ds = &ids_scenario_setting.
						, ids_rhs_ds = WORK.tmp_scenarios_in_rsm
						, i_conditions = scenario_name:name scenario_version:scenarioVersion
						, ods_output_ds = WORK.tmp_scenarios_found_in_rsm)
	%LoadScenarioValueFromRSM(ids_used_scenarios = WORK.tmp_scenarios_found_in_rsm
										, ods_scenario_value = WORK.tmp_scenario_value)
	%&RSUDS.Delete(WORK.tmp_scenarios_in_rsm WORK.tmp_scenarios_found_in_rsm)
	%SaveScenarioValueDS(iods_raw_scenario_data = WORK.tmp_scenario_value)
%mend ScnMgr__CreateDSFromRSM;

%macro SASIRMSetupHelper(i_fa_id =);
	%include "&G_SYS_CONST_PATH_SASIRM./fa.&i_fa_id./irm/source/sas/ucmacros/irm_setup.sas";
	%irm_setup(source_path = &G_SYS_CONST_PATH_SASIRM.
				, fa_id = fa.&i_fa_id.)
%mend SASIRMSetupHelper;

/*-----------------------------------------------------------*/
/* 計算設定で指定されているシナリオリスト
/*
/* NOTE: 同一シナリオ名の異なるバージョンは同時に使用不可
/*-----------------------------------------------------------*/
%macro ScnMgr__LoadScenarioSetting(ods_used_scenario_list =);
	%&RSULogger.PutNote(Loading scenario configuration...)
	%&DataController.LoadExcel(i_excel_file_path = &G_DIR_USER_DATA_RSLT_DIR1_STG./&G_SETTING_CALC_SET_FILE_NAME.
										, i_setting_excel_file_path = &G_FILE_SYSTEM_SETTING.
										, i_schema_name = &G_CONST_SHCEMA_TYPE_SCENARIO.
										, i_sheet_name = &G_SETTING_CALC_SCEN_SHEET_NAME.
										, ods_output_ds = WORK.tmp_scenario_list_in_setting)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load scenario file)
		%return;
	%end;
	%&RSUDS.Let(i_query = WORK.tmp_scenario_list_in_setting(where = (use_flg = '1'))
					, ods_dest_ds = WORK.tmp_scenario_list_in_setting(drop = use_flg))
	%if (%&RSUDS.IsDSEmpty(WORK.tmp_scenario_list_in_setting)) %then %do;
		%&RSUDS.Delete(WORK.tmp_scenario_list_in_setting)
		%&RSULogger.PutInfo(No scenario is used. Check data.)
		%return;
	%end;

	data WORK.tmp_scenario_list_in_setting;
		attrib
			scenario_info length = $200.
		;
		set WORK.tmp_scenario_list_in_setting;
		if (not missing(scenario_version)) then do;
			scenario_info = catx(';', scenario_name, scenario_version);
		end;
		else do;
			scenario_info = scenario_name;
		end;
	run;
	quit;
	%&RSUDS.Delete(&ods_used_scenario_list.)
	%&Utility.ShowDSSingleColumn(ids_source_ds = WORK.tmp_scenario_list_in_setting
										, i_variable_def = scenario_info
										, i_title = [Scenario(s) to be used])

	/* Check（同じシナリオ名で異なるバージョンの同時使用は不可）*/
	proc sql noprint;
		create table WORK.tmp_scenario_name_count
		as
		select
			count(*) as count
			, scenario_name
		from
			WORK.tmp_scenario_list_in_setting
		group by
			scenario_name
		having
			count ne 1
		;
	quit;
	%if (%&RSUDS.IsDSEmpty(WORK.tmp_scenario_name_count)) %then %do;
		%&RSULogger.PutInfo(All scenarios are unique)
	%end;
	%else %do;
		%local _count;
		%local _dsid_count;
		%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_scenario_name_count
											, i_vars = _count:count
											, ovar_dsid = _dsid_count));
			%if (&_count. ne 1) %then %do;
				%&RSULogger.PutInfo(&scenario_name. is not unique.)
			%end;
		%end;
		%&RSUError.Throw(Scenario setting is invalid)
		%return;
	%end;
	%&RSUDS.Delete(WORK.tmp_scenario_name_count)

	%&RSUDS.Move(i_query = WORK.tmp_scenario_list_in_setting
					, ods_dest_ds = &ods_used_scenario_list.)
%mend ScnMgr__LoadScenarioSetting;

/*---------------------------------------------------*/
/* シナリオマネージャに登録されているシナリオリスト取得
/*---------------------------------------------------*/
%macro GenerateScenarioListInRSM(i_host =
											, i_port =
											, i_tgt_ticket =
											, i_user_id =
											, i_password =
											, ods_scenario_list =);
	%&RSULogger.Putinfo(Retrieving scenario list from Risk Scenario Manager)
	%local _httpSucess;
	%local _responseStatus;
	%if (not %&RSUUtil.IsMacroBlank(i_password)) %then %do;
		%&RSULogger.PutInfo(Basic Auth is used(user Id and password are given.))
		%irm_rest_get_rsm_scenario_info(host = &i_host.
												, port = &i_port.
												, username = &i_user_id.
												, password = &i_password.
												, outSuccess = _httpSucess
												, outds = &ods_scenario_list.
												, outResponseStatus = _responseStatus
												, debug = false)
	%end;
	%else %do;
		%&RSULogger.PutInfo(Ticket Granted Ticket is given)
		%irm_rest_get_rsm_scenario_info(host = &i_host.
												, port = &i_port.
												, tgt_ticket = &i_tgt_ticket.
												, outSuccess = _httpSucess
												, outds = &ods_scenario_list.
												, outResponseStatus = _responseStatus
												, debug = false)
	%end;
	%&RSUDS.Let(i_query = &ods_scenario_list.(keep = name scenarioVersion id)
					, ods_dest_ds = &ods_scenario_list.)
	%&RSULogger.PutInfo(%&RSUDS.GetCount(&ods_scenario_list.) scenario(s) found in Risk Scenario Manager)
%mend GenerateScenarioListInRSM;

/*------------------------------------------------------------------*/
/* 計算設定で指定されているシナリオのうち、RSMに存在するものを取得
/*------------------------------------------------------------------*/
%macro LoadScenarioValueFromRSM(ids_used_scenarios =
										, ods_scenario_value =);
	%&RSUDS.Delete(WORK.tmp_scenarios_in_rsm)
	%local _scenario_name;
	%local _scenario_version;
	%local _scenario_id;
	%local _dsid_scenario;
	%local _status_label;
	%local _scenario_label;
	%do %while(%&RSUDS.ForEach(i_query = &ids_used_scenarios.
										, i_vars = _scenario_name:scenario_name
													_scenario_version:scenario_version
													_scenario_id:id
										, ovar_dsid = _dsid_scenario));
		%let _status_label = %&RSUUtil.Choose(, Not found, Found);
		%if (%&RSUUtil.IsMacroBlank(_scenario_id)) %then %do;
			%let _status_label = Not found;
			%let _scenario_label = &_scenario_name.:&_scenario_version.;
		%end;
		%else %do;
			%let _status_label = Found;
			%let _scenario_label = (&_scenario_id.)&_scenario_name.:&_scenario_version.;
		%end;
		%&RSULogger.PutInfo(&_scenario_label..&_status_label.)								
	%end;

	%&RSUDS.Delete(&ods_scenario_value.)
	%do %while(%&RSUDS.ForEach(i_query = &ids_used_scenarios.
										, i_vars = _scenario_name:scenario_name
													_scenario_version:scenario_version
													_scenario_id:id
										, ovar_dsid = _dsid_scenario));
		%if (not %&RSUUtil.IsMacroBlank(_scenario_id)) %then %do;
			%GetScenarioValue(i_scenario_id = &_scenario_id.
									, i_scenario_name = &_scenario_name.
									, i_scenario_version = &_scenario_version.
									, i_host = &i_host.
									, i_port = &i_port.
									, i_ticket = &i_ticket.
									, i_user_id = &i_user_id.
									, i_password = &i_password.
									, ods_scenario_value = WORK.tmp_loaded_scenario_value)
			%&RSUDS.Append(iods_base_ds = &ods_scenario_value.
								, ids_data_ds = WORK.tmp_loaded_scenario_value)
			%&RSUDS.Delete(WORK.tmp_loaded_scenario_value)
		%end;
	%end;
%mend LoadScenarioValueFromRSM;

/*------------------------------------*/
/* シナリオ値を取得
/*------------------------------------*/
%macro GetScenarioValue(i_scenario_id =
								, i_scenario_name =
								, i_scenario_version =
								, i_host =
								, i_port =
								, i_ticket =
								, i_user_id =
								, i_password =
								, ods_scenario_value =);
	%&RSULogger.PutParagraph(Retrieving scenario value of "(&i_scenario_id.)&i_scenario_name.:&i_scenario_version." from SAS(R) Risk Scenario Manager)
	%local _httpSucess;
	%local _responseStatus;
	%irm_rest_get_rsm_scenario(host = &i_host.
										, port = &i_port.
										, username = &i_user_id.
										, password = &i_password.
										, tgt_ticket = &i_ticket.
										, key = &i_scenario_id.
										, outds = &ods_scenario_value.
										, outSuccess = _httpSucess
										, outResponseStatus = _responseStatus
										, debug = false
										, logOptions =
										, restartLUA = Y
										, clearCache = Y)
	/* Profile */
	%&RSUDS.GetUniqueList(i_query = &ods_scenario_value.(keep = variable_name)
								, i_by_variables = variable_name
								, ods_output_ds = WORK.tmp_risk_factors)
	%local _risk_factors;
	proc sql noprint;
		select
			variable_name into :_risk_factors separated by '&RSUComma.'
		from
			WORK.tmp_risk_factors
		;
	quit;
	%&RSUDS.Delete(WORK.tmp_risk_factors)
	%&RSULogger.PutBlock([Scenario profile]
								, Scenario ID: &i_scenario_id.
								, Name(version): &i_scenario_name(&i_scenario_version.)
								, # of observation: %&RSUDS.GetCount(&ods_scenario_value.)
								, Risk factors: (&_risk_factors.))
%mend GetScenarioValue;

%macro SaveScenarioValueDS(iods_raw_scenario_data =);
	data &iods_raw_scenario_data.;
		attrib
			scenario_id length = $200.
			&G_CONST_VAR_TIME. length = 8.
			&G_CONST_VAR_VARIABLE_REF_NAME. length = $100.
			&G_CONST_VAR_VALUE. length = $100.
		;
		set &iods_raw_scenario_data.;
		scenario_id = catx(';', scenario_name, scenario_version);
		&G_CONST_VAR_VARIABLE_REF_NAME. = variable_name;
		&G_CONST_VAR_TIME. = year(date) * 10000 + month(date) * 100 + day(date);
		&G_CONST_VAR_VALUE. = compress(put(change_value, BEST.));
		keep
			scenario_id
			&G_CONST_VAR_TIME.
			&G_CONST_VAR_VARIABLE_REF_NAME.
			&G_CONST_VAR_VALUE.
		;
	run;
	quit;
	%&Utility.SaveDS(ids_source_ds = &iods_raw_scenario_data.
						, i_save_as = %&DataObject.DSVariablePart(i_suffix = Scenario))
%mend SaveScenarioValueDS;

/**======================================**/
/* Formula内のシナリオ参照リスト
/*
/* NOTE: "Scenario{([^}]+)}"で抽出
/**======================================**/
%macro ScnMgr__ExtractRiskFactors(ids_formula_definition =
											, ods_risk_factors =);
	%&RSULogger.PutSubsection(Risk factors in formula)
	%&RSULogger.PutNote(Finding risk factor reference in formula definition)
	%local /readonly _REGEX_RISK_FACTOR = (&G_CONST_REGEX_VPR_FUNC_DELM.)(&G_CONST_VPR_FUNC_SCENARIO.&G_CONST_REGEX_VPR_FUNC_ARGUMENT.);
	data WORK.tmp_referred_risk_factors_form(keep =  risk_factor);
		set &ids_formula_definition.;
		attrib
			risk_factor length = $100.
			__tmp_decmp_definition length = $3000.
		;
		if (not missing(formula_definition_rhs)) then do;
			__tmp_decmp_regex_model = prxparse("/&_REGEX_RISK_FACTOR./o");
			__tmp_decmp_definition = strip(formula_definition_rhs);
			__tmp_decmp_org_length = lengthn(__tmp_decmp_definition);
			__tmp_decmp_start = 1;
			__tmp_decmp_stop = __tmp_decmp_org_length;
			__tmp_decmp_position = 1;
			__tmp_decmp_length = 0;

			call prxnext(__tmp_decmp_regex_model, __tmp_decmp_start, __tmp_decmp_stop, __tmp_decmp_definition, __tmp_decmp_position, __tmp_decmp_length);
			do while(0 < __tmp_decmp_position);
				risk_factor = prxposn(__tmp_decmp_regex_model, &G_CONST_VPR_FUNC_POS_VAR_REF. + 2, __tmp_decmp_definition);
				output;
				call prxnext(__tmp_decmp_regex_model, __tmp_decmp_start, __tmp_decmp_stop, __tmp_decmp_definition, __tmp_decmp_position, __tmp_decmp_length);
			end;
		end;
	run;
	quit;

	%if (%&RSUDS.IsDSEmpty(WORK.tmp_referred_risk_factors_form)) %then %do;
		%&RSULogger.PutInfo(No scenario reference found in formula definition)
		%return;
	%end;

	%&RSUDS.GetUniqueList(i_query = WORK.tmp_referred_risk_factors_form
								, i_by_variables = risk_factor
								, ods_output_ds = &ods_risk_factors.)
	/* Profile */
	%local _risk_foctors;
	proc sql noprint;
		select
			risk_factor into :_risk_foctors separated by '&RSUComma.'
		from
			&ods_risk_factors.
		;
	quit;
	%&RSULogger.PutBlock([Scenarios in formula]
								, &_risk_foctors.)
	%&RSUDS.Delete(WORK.tmp_referred_risk_factors_form)	
%mend ScnMgr__ExtractRiskFactors;

/**====================================**/
/* シナリオデータの確認
/*
/* NOTE: チェック項目
/* NOTE: 1. 計算設定で使用が指示されているシナリオが揃っていること
/* NOTE: 2. すべてのシナリオにおいてすべてのリスクファクターが揃っていること
/**====================================**/
%macro ScnMgr__CheckScenario(ids_used_scenario_list =
									, ids_referred_risk_factors =);
	%&RSULogger.PutSubsection(Scenario validation)
	%&RSUDS.Let(i_query = %&LayerManager.DSDataLayer(i_data_id = Scenario
																	, i_layer_type = &G_CONST_VAR_ROLE_SCENARIO.)
					, ods_dest_ds = WORK.tmp_unique_scenario_list)
	/* 1 */
	%&RSULogger.PutNote(Checking if all scenarios ready)
	%&RSUDS.LeftJoin(ids_lhs_ds = &ids_used_scenario_list.
						, ids_rhs_ds = WORK.tmp_unique_scenario_list
						, i_conditions = scenario_info:scenario_id
						, ods_output_ds = WORK.tmp_scenario_list_ex)
	%if (%&RSUDS.GetCount(WORK.tmp_scenario_list_ex(where = (missing(scenario_id)))) = 0) %then %do;
		%&RSULogger.PutInfo(All scenarios ready)
	%end;
	%else %do;
		%local _scenario_info;
		%local _dsid_scenario_info;
		%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_scenario_list_ex(where = (missing(scenario_id)))
											, i_vars = _scenario_info:scenario_info
											, ovar_dsid = _dsid_scenario_info));
			%&RSULogger.PutError(&_scenario_info. not ready.)
		%end;
	%end;
	%&RSUDS.Delete(WORK.tmp_scenario_list_ex)
	/* 2 */
	%&RSULogger.PutNote(Checking if all risk facotos ready)
	%local _scenario_id;
	%local _layer_id;
	%local _dsid_scenario_id;
	%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_unique_scenario_list
										, i_vars = _scenario_id:scenario_id
													_layer_id:&G_CONST_LAYER_ID_SCENARIO.Scenario
										, ovar_dsid = _dsid_scenario_id));
		%&RSULogger.PutParagraph(Serching risk factors in scenario "&_scenario_id.")
		%&RSUDS.GetUniqueList(i_query = %&DataObject.DSVariablePart(i_suffix = Scenario)(where = (&G_CONST_LAYER_ID_SCENARIO.Scenario = &_layer_id.))
									, i_by_variables = &G_CONST_VAR_VARIABLE_REF_NAME.
									, ods_output_ds = WORK.tmp_loaded_risk_factors)
		%&RSUDS.LeftJoin(ids_lhs_ds = &ids_referred_risk_factors.
							, ids_rhs_ds = WORK.tmp_loaded_risk_factors
							, i_conditions = risk_factor:&G_CONST_VAR_VARIABLE_REF_NAME.
							, ods_output_ds = WORK.tmp_risk_facators_ex)
		%if (%&RSUDS.GetCount(WORK.tmp_risk_facators_ex(where = (missing(&G_CONST_VAR_VARIABLE_REF_NAME.)))) = 0) %then %do;
			%&RSULogger.PutInfo(All risk factors defined in scenario "&_scenario_id.")
		%end;
		%else %do;
			%local _risk_factor;
			%local _dsid_risk_factor;
			%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_risk_facators_ex(where = (missing(&G_CONST_VAR_VARIABLE_REF_NAME.)))
												, i_vars = _risk_factor:risk_factor
												, ovar_dsid = _dsid_risk_factor));
				%&RSULogger.PutInfo(&_risk_factor. not found in scenario "&_scenario_id.")
			%end;
		%end;
		%&RSUDS.Delete(WORK.tmp_risk_facators_ex)
	%end;
	%&RSUDS.Delete(WORK.tmp_unique_scenario_list)
%mend ScnMgr__CheckScenario;

%macro ScnMgr__Trim();
	%&RSULogger.PutNote(Finding common time range among all scenarios...)
	proc sql;
		create table WORK.tmp_scenario_range
		as
		select
			min(&G_CONST_VAR_TIME.) as time_min
			, max(&G_CONST_VAR_TIME.) as time_max
		from
			%&DataObject.DSVariablePart(i_suffix = Scenario)
		group by
			&G_CONST_LAYER_ID_SCENARIO.Scenario
		;
	quit;
	%local _time_min;
	%local _time_max;
	proc sql noprint;
		select
			max(time_min)
			, min(time_max) into :_time_min trimmed, :_time_max trimmed
		from
			WORK.tmp_scenario_range
		;
	quit;

	%&RSUDS.Let(i_query = %&DataObject.DSVariablePart(i_suffix = Scenario)(where = (&_time_min. <= &G_CONST_VAR_TIME. and &G_CONST_VAR_TIME. <= &_time_max.))
					, ods_dest_ds = %&DataObject.DSVariablePart(i_suffix = Scenario))
	%&RSULogger.PutBlock(Scenario range: [&_time_min. - &_time_max.])
%mend ScnMgr__Trim;