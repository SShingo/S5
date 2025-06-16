/****************************************************************/
/* Constant.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/****************************************************************/
/* グローバル定数 */
%RSUSetConstant(G_CONST_PROGRAM_VERSION, v110)
%RSUSetConstant(G_CONST_DATA_DIR_TYPE_STG, DIR1_STG)		/* ソートした時に優先順位が上位に来るよう数字を付与 */
%RSUSetConstant(G_CONST_DATA_DIR_TYPE_PREDEF, DIR2_PREDEF)	/* ソートした時に優先順位が上位に来るよう数字を付与 */
%RSUSetConstant(G_CONST_ACCOUNT_TITLE_INDENT, %quote('    '))

%RSUSetConstant(G_CONST_SHCEMA_TYPE_FORMULA, Formula)
%RSUSetConstant(G_CONST_SHCEMA_TYPE_MODEL, Model)
%RSUSetConstant(G_CONST_SHCEMA_TYPE_SCENARIO, Scenario)

%RSUSetConstant(G_CONST_LAYER_ID_PREFIX, layer_id_)
%RSUSetConstant(G_CONST_LAYER_ID_SPACE, &G_CONST_LAYER_ID_PREFIX.sp___)
%RSUSetConstant(G_CONST_LAYER_ID_SCENARIO, &G_CONST_LAYER_ID_PREFIX.sc___)
%RSUSetConstant(G_CONST_LAYER_ID_TIME, &G_CONST_LAYER_ID_PREFIX.ti___)
%RSUSetConstant(G_CONST_LAYER_ID_FORMULA_SYS_ID, &G_CONST_LAYER_ID_PREFIX.fs___)
%RSUSetConstant(G_CONST_VAR_ROLE_VALUE_VARIABLE, VALUE_VARIABLE_NAME)
%RSUSetConstant(G_CONST_VAR_ROLE_TIME, TIME)
%RSUSetConstant(G_CONST_VAR_ROLE_SPACE, SPACE)
%RSUSetConstant(G_CONST_VAR_ROLE_SCENARIO, SCENARIO)
%RSUSetConstant(G_CONST_VAR_ROLE_FORMULA_SYS_ID, FORMULA_SYSTEM_ID)

%RSUSetConstant(G_CONST_REGEX_CALC_SETTING_DELM, [^\$])
%RSUSetConstant(G_CONST_REGEX_CALC_SETTING, \$\{([^\}]+)\})
%RSUSetConstant(G_CONST_REGEX_STAT_FUNC_DELM, [^\{])
%RSUSetConstant(G_CONST_REGEX_STAT_FUNCTIONS, \{Agg\} \{Sum\} \{Avg\} \{Min\} \{Max\} \{Prod\} \{Count\})
%RSUSetConstant(G_CONST_REGEX_VPR_FUNC_DELM, [^\w])
%RSUSetConstant(G_CONST_VPR_FUNC_SCENARIO, Scenario)
%RSUSetConstant(G_CONST_VPR_FUNC_MODEL, Model)
%RSUSetConstant(G_CONST_VPR_FUNC_TIME, Time)
%RSUSetConstant(G_CONST_VPR_FUNC_REF, Ref)
%RSUSetConstant(G_CONST_VPR_FUNC_PARAM_TABLE, ParameterTable)
%RSUSetConstant(G_CONST_REGEX_VPR_FUNC_ARGUMENT, (\[(\w+)\])?\{([^\}@]+)(@\s*((\d{<TIME_DIGIT>})|(-\d+)))?\s*\})
%RSUSetConstant(G_CONST_VPR_FUNC_POS_VAR_REF, 1)
%RSUSetConstant(G_CONST_VPR_FUNC_POS_TIME_ABS, 4)
%RSUSetConstant(G_CONST_VPR_FUNC_POS_TIME_REL, 5)
%RSUSetConstant(G_CONST_REGEX_MODEL_REF, Model\{([^\}]+)\})
%RSUSetConstant(G_CONST_REGEX_PARAMETER_TABLE, &G_CONST_VPR_FUNC_PARAM_TABLE.%str(\{([^,]+),\s*([^\}]+)\}))
%RSUSetConstant(G_CONST_PARAM_TABLE_POS_TABLE, 3)
%RSUSetConstant(G_CONST_PARAM_TABLE_POS_KEY, 4)
%RSUSetConstant(G_CONST_VARRIABLE_NAME_VALUE, value)

/* ライブラリ */
%RSUSetConstant(G_CONST_LIB_WORK, L_WORK)
%RSUSetConstant(G_CONST_LIB_RSLT, L_RSLT)
%RSUSetConstant(G_CONST_LIB_HIST, L_HIST)
%RSUSetConstant(G_CONST_LIB_VA_DM, L_VADM)
%RSUSetConstant(G_CONST_LIB_MODEL_DM, L_MDLDM)
%RSUSetConstant(G_CONST_LIB_LASR_QV, L_LASRQV)
%RSUSetConstant(G_CONST_LIB_LASR_DM, L_LASRDM)

/* データセット */
%RSUSetConstant(G_CONST_DS_CALCULATION_SETTING, &G_CONST_LIB_WORK..calculate_setting)
%RSUSetConstant(G_CONST_DS_PARAMETER_TABLE, &G_CONST_LIB_WORK..parameter_table)
%RSUSetConstant(G_CONST_DS_MODEL_DEFINITION, &G_CONST_LIB_WORK..model_definiion)
%RSUSetConstant(G_CONST_DS_SCENARIO_LIST, &G_CONST_LIB_WORK..scenario_list)
%RSUSetConstant(G_CONST_DS_SCENARIO_VALUE, &G_CONST_LIB_WORK..scenario_value)
%RSUSetConstant(G_CONST_DS_LAYER_STRUCT_DATA, &G_CONST_LIB_WORK..layer_structure_data)
%RSUSetConstant(G_CONST_DS_FORMULA_DEFINITION, &G_CONST_LIB_WORK..formula_definition)
%RSUSetConstant(G_CONST_DS_RUN_HISTORY, &G_CONST_LIB_HIST..run_history)
%RSUSetConstant(G_CONST_DS_MODEL_DATAMART, &G_CONST_LIB_MODEL_DM..model)
%RSUSetConstant(G_CONST_DS_MODEL_UPDATE, &G_CONST_LIB_WORK..model_update)
%RSUSetConstant(G_CONST_DS_TIME_AXIS, &G_CONST_LIB_WORK..time_axis)

/* 固定変数名 */
%RSUSetConstant(G_CONST_VAR_TIME, _time_)
%RSUSetConstant(G_CONST_VAR_HORIZON_INDEX, _horizon_index_)
%RSUSetConstant(G_CONST_VAR_VALUE, value)
%RSUSetConstant(G_CONST_VAR_VARIABLE_REF_NAME, variable_ref_name)

/* Formula */
%RSUSetConstant(G_CONST_VAR_FORM_SYSTEM_ID, formula_system_id___)

/* Model */
%RSUSetConstant(G_CONST_VAR_MODEL_ID, model_id)
%RSUSetConstant(G_CONST_VAR_MODEL_VERSION, model_version)
%RSUSetConstant(G_CONST_VAR_MODEL_DEFINITION, model_definition)

/* Scenario */
%RSUSetConstant(G_CONST_VAR_SCENARIO_NAME, scenario_name)
%RSUSetConstant(G_CONST_VAR_SCENARIO_VERSION, model_version)
%RSUSetConstant(G_CONST_VAR_USE_FLG, model_definition)

/* DM */
%RSUSetConstant(G_CONST_VAR_DM_DM_KEY, dm_key)
%RSUSetConstant(G_CONST_VAR_DM_USER_ID, user_id)
%RSUSetConstant(G_CONST_VAR_DM_CYCLE_ID, cycle_id)
%RSUSetConstant(G_CONST_VAR_DM_CYCLE_NAME, cycle_name)
%RSUSetConstant(G_CONST_VAR_DM_REG_DATETIME, registered_date)

/* Run History */
%RSUSetConstant(G_CONST_VAR_RUN_HIST_RUNNING_ID, running_id)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_PROGRAM_VER, program_version)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_CYCLE_ID, cycle_id)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_CYCLE_NAME, cycle_name)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_USER_ID, user_id)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_PROC_TYPE, process_type)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_MEMO, memo)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_START_TIME, start_time)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_END_TIME, end_time)
%RSUSetConstant(G_CONST_VAR_RUN_HIST_BACKUP_DIR, backup_dir)

/* 共通マクロ変数 */
%global g_macro_status;
%let g_macro_status = 0;
%global g_macro_status_set;
%let g_macro_status = 0;
