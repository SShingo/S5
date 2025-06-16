/****************************************************************/
/* EnvironmentManager.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/****************************************************************/
%RSUSetConstant(EnvironmentManager, EnvMgr__)

%macro ShowTitle();
	options notes;
	%put NOTE- ///////////////////////////////////////////////////////////////////////////////;
	%put NOTE- ///////////////////////////////////////////////////////////////////////////////;
	%put NOTE-;
	%put NOTE-                    Scenario Simulator Suite on SAS Stratum;
	%put NOTE-                                       by;
	%put NOTE-                     Shingo Suzuki (shingo.suzuki@sas.com);
	%put NOTE-;
	%put NOTE-                            (c)2022 SAS Institute Japan, Risk Solution Unit(RSU);
	%put NOTE-;
	%put NOTE- ///////////////////////////////////////////////////////////////////////////////;
	%put NOTE- ///////////////////////////////////////////////////////////////////////////////;
	options nonotes;
%mend ShowTitle;

/**======================================**/
/* プロセス準備
/*
/* ! タスクごとにセッションが初期化されているので、毎タスクで呼ぶ必要あり。
/**======================================**/
%macro EnvMgr__PrepareProcess(i_user_id =
										, i_process_name =);
	%ShowTitle()
	%&RSULogger.PutSection(Preparing process)

	/* ディレクトリ構造 */
	%local _is_ok;
	%DefineDirectoryStructure(i_application_root = &G_APP_ROOT_S5.
									, i_process_name = &i_process_name.
									, i_user_id = &i_user_id.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to defining directory structure. Check directories)
		%return;
	%end; 

	/* 設定ファイル */
	%CheckRequiredFile()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Required file not found. Check file)
		%return;
	%end; 

	/* グローバル設定 */
	%LoadGlobalSettings(i_process_name = &i_process_name.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load global setting file)
		%return;
	%end;

	/* VA関連 */
	%&VAManager.ConfigureLASR(i_process_name = &i_process_name.
									, i_user_id = &i_user_id.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to configure LASR server)
		%return;
	%end;

	/* Library設定 */
	%AssignLibraries()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to assign library.)
		%return;
	%end;

	/* Stratum 設定 */
	%&Stratum.ConfigureStratumSystem()

	/* Model DM */
	%&ModelManager.InitializeDM();

	/* 履歴管理 */
	%&RunHistory.Prepare()

	%&RSULogger.PutInfo(System is ready.)
%mend EnvMgr__PrepareProcess;

/*--------------------------------------------------------------------------------------------------*/
/* システムディレクトリ構造設定
/*
/* <Root>  -------------------------------- &i_application_root.
/*  │
/*  ├ program ----------------------------- G_APP_S5_PROGRAM_ROOT.
/*  |  └ macros
/*  │
/*  ├ tool
/*  │
/*  └ data -------------------------------- G_DIR_DATA_ROOT
/*     ├ dm ------------------------------- G_DATA_DIR_DM
/*     │  ├ ModelManagement --------------- G_DIR_DATA_DM_MODEL_MANAGEMENT > L_MDLDM
/*     │  └ <ProcessType> ----------------- G_DIR_DATA_DM_PROCESS > L_VADM
/*     ├ config
/*     │  └ <ProcessType> ----------------- G_DIR_PROCESS_CONFIG
/*     ├ predefined
/*     │  └ <ProcessType> ----------------- G_DIR_PREDEFINED_PROCESS
/*     └ users
/*        └ <user-id> --------------------- G_DIR_USER_DATA_ROOT
/*           ├ history -------------------- G_DIR_USER_DATA_HISTORY > L_HIST
/*           │  └ <result*>
/*           │     └ in
/*           │        ├ config
/*           │        ├ predefined
/*           │        └ staging
/*           ├ staging -------------------- G_DIR_USER_DATA_STAGING > L_STG
/*           ├ result - ------------------- G_DIR_USER_DATA_RSLT > L_RSLT
/*           │  └ in
/*           │     ├ config --------------- G_DIR_USER_DATA_RSLT_CONF
/*           │     ├ predefined ----------- G_DIR_USER_DATA_RSLT_DIR2_PREDEF
/*           │     └ staging -------------- G_DIR_USER_DATA_RSLT_DIR1_STG
/*           └ work ----------------------- G_DIR_USER_DATA_WORK > L_WORK
/*--------------------------------------------------------------------------------------------------*/
%macro DefineDirectoryStructure(i_application_root = 
										, i_process_name =
										, i_user_id =);
	%&RSULogger.PutSubsection(Directory structure)
	/* パス設定 */
	%&RSULogger.PutNote(Definining system direcotries)
	%local _is_defined;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_DATA_ROOT
								, i_dir_path = &i_application_root./data
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &i_application_root./data is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_PROCESS_CONFIG
								, i_dir_path = &G_DIR_DATA_ROOT./config/&i_process_name.
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_DATA_ROOT./config/&i_process_name. is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_PREDEFINED_PROCESS
								, i_dir_path = &G_DIR_DATA_ROOT./predefined/&i_process_name.
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_DATA_ROOT./predefined/&i_process_name. is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_USER_DATA_ROOT
								, i_dir_path = &G_DIR_DATA_ROOT./users/&i_user_id.
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_DATA_ROOT./users/&i_user_id. is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_USER_DATA_HISTORY
								, i_dir_path = &G_DIR_USER_DATA_ROOT./history
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_USER_DATA_ROOT./history is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_USER_DATA_STAGING
								, i_dir_path = &G_DIR_USER_DATA_ROOT./staging
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_USER_DATA_ROOT./staging is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_USER_DATA_RSLT
								, i_dir_path = &G_DIR_USER_DATA_ROOT./result
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_USER_DATA_ROOT./result is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_USER_DATA_RSLT_CONF
								, i_dir_path = &G_DIR_USER_DATA_RSLT./in/config
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_USER_DATA_RSLT./in/config is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_USER_DATA_RSLT_DIR1_STG
								, i_dir_path = &G_DIR_USER_DATA_RSLT./in/staging
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_USER_DATA_RSLT./in/staging is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_USER_DATA_RSLT_DIR2_PREDEF
								, i_dir_path = &G_DIR_USER_DATA_RSLT./in/predefined
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_USER_DATA_RSLT./in/predefined is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_USER_DATA_WORK
								, i_dir_path = &G_DIR_USER_DATA_ROOT./work
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_USER_DATA_ROOT./work is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_DATA_DM_PROCESS
								, i_dir_path = &G_DIR_DATA_ROOT./dm/&i_process_name.
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_DATA_ROOT./dm/&i_process_name. is invalid)
		%return;
	%end;
	%SetDirectoryConstant(i_constant_macro_var = G_DIR_DATA_DM_MODEL_MANAGEMENT
								, i_dir_path = &G_DIR_DATA_ROOT./dm/ModelManagement
								, i_is_defined = _is_defined)
	%if (not &_is_defined.) %then %do;
		%&RSUError.Throw(Directory &G_DIR_DATA_ROOT./dm/ModelManagement is invalid)
		%return;
	%end;
%mend DefineDirectoryStructure;

%macro CheckRequiredFile();
	%&RSULogger.PutSubsection(Required files)
	%&RSULogger.PutNote(Checking required files)
	%RSUSetConstant(G_FILE_SYSTEM_SETTING, &G_DIR_DATA_ROOT./config/system_setting.xlsx)
	%if (%&RSUFile.Exists(&G_FILE_SYSTEM_SETTING.)) %then %do;
		%&RSULogger.PutInfo(&G_FILE_SYSTEM_SETTING... Found)
	%end;
	%else %do;
		%&RSUError.Throw(&G_FILE_SYSTEM_SETTING... Not Found)
		%return;
	%end;
	%RSUSetConstant(G_FILE_APPLICATION_CONFIG, &G_DIR_PROCESS_CONFIG./AppConfig.xlsx)
	%if (%&RSUFile.Exists(&G_FILE_APPLICATION_CONFIG.)) %then %do;
		%&RSULogger.PutInfo(&G_FILE_APPLICATION_CONFIG... Found)
	%end;
	%else %do;
		%&RSUError.Throw(&G_FILE_APPLICATION_CONFIG... Not Found)
		%return;
	%end;
%mend CheckRequiredFile;

%macro SetDirectoryConstant(i_constant_macro_var =
									, i_dir_path =
									, i_is_defined =);
	%if (%&RSUFile.Exists(&i_dir_path.)) %then %do;
		%&RSULogger.PutInfo(&i_dir_path.... OK);
		%RSUSetConstant(&i_constant_macro_var., &i_dir_path.)
		%let &i_is_defined. = %&RSUBool.True;
	%end;
	%else %do;
		%&RSULogger.PutInfo(&i_dir_path.... NG);
		%let &i_is_defined. = %&RSUBool.False;
	%end;
%mend SetDirectoryConstant;

%macro AssignLibraries();
	%&RSULogger.PutSubsection(Libraries)
	%&RSULogger.PutNote(Assigning library...)
	/* ライブラリ設定 */
	%local _is_library_ok;
	%AssignLibrary(i_library_name = &G_CONST_LIB_HIST.
						, i_library_path = &G_DIR_USER_DATA_HISTORY.
						, ovar_is_library_ok = _is_library_ok)
	%if (not &_is_library_ok.) %then %do;
		%&RSUError.Throw(Failed to assign physical path &G_DIR_USER_DATA_HISTORY. to &G_CONST_LIB_HIST.)
		%return;
	%end;
	%AssignLibrary(i_library_name = &G_CONST_LIB_RSLT.
						, i_library_path = &G_DIR_USER_DATA_RSLT.
						, ovar_is_library_ok = _is_library_ok)
	%if (not &_is_library_ok.) %then %do;
		%&RSUError.Throw(Failed to assign physical path &G_DIR_USER_DATA_RSLT. to &G_CONST_LIB_RSLT.)
		%return;
	%end;
	%AssignLibrary(i_library_name = &G_CONST_LIB_WORK.
						, i_library_path = &G_DIR_USER_DATA_WORK.
						, ovar_is_library_ok = _is_library_ok)
	%if (not &_is_library_ok.) %then %do;
		%&RSUError.Throw(Failed to assign physical path &G_DIR_USER_DATA_WORK. to &G_CONST_LIB_WORK.)
		%return;
	%end;
	%AssignLibrary(i_library_name = &G_CONST_LIB_VA_DM.
						, i_library_path = &G_DIR_DATA_DM_PROCESS.
						, ovar_is_library_ok = _is_library_ok)
	%if (not &_is_library_ok.) %then %do;
		%&RSUError.Throw(Failed to assign physical path &G_DIR_DATA_DM_PROCESS. to &G_CONST_LIB_VA_DM.)
		%return;
	%end;
	%AssignLibrary(i_library_name = &G_CONST_LIB_MODEL_DM.
						, i_library_path = &G_DIR_DATA_DM_MODEL_MANAGEMENT.
						, ovar_is_library_ok = _is_library_ok)
	%if (not &_is_library_ok.) %then %do;
		%&RSUError.Throw(Failed to assign physical path &G_DIR_DATA_DM_MODEL_MANAGEMENT. to &G_CONST_LIB_MODEL_DM.)
		%return;
	%end;
	%&VAManager.AssignLASRLibrary()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to assign library on LASR server)
		%return;
	%end;
%mend AssignLibraries;

/*---------------------*/
/* ライブラリ設定
/*---------------------*/
%macro AssignLibrary(i_library_name =
							, i_library_path =
							, ovar_is_library_ok =);
	libname &i_library_name. " &i_library_path." compress = yes;
	%if (%&RSULib.IsAssigned(&i_library_name.)) %then %do;
		%&RSULogger.PutInfo(&i_library_name.(%&RSULib.GetPath(&i_library_name.)).... OK)
		%let &ovar_is_library_ok. = %&RSUBool.True;
	%end;
	%else %do;
		%&RSULogger.PutInfo(&i_library_name.(&i_library_path.).... NG)
		%let &ovar_is_library_ok. = %&RSUBool.False;
	%end;
%mend AssignLibrary;

/*-------------------*/
/* グローバル設定
/*-------------------*/
%macro LoadGlobalSettings(i_process_name =);
	/* 設定ファイルマクロ変数 */
	%&RSULogger.PutSubsection(Global constants defined by system setting file)
	%&RSULogger.PutNote(Loading global settings)
	%&DataController.LoadExcel(i_excel_file_path = &G_FILE_SYSTEM_SETTING.
										, i_setting_excel_file_path = &G_FILE_SYSTEM_SETTING.
										, i_sheet_name = Global Setting
										, ods_output_ds = WORK.tmp_system_setting)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load excel sheet "Global Setting" in excel file &G_FILE_SYSTEM_SETTING.)
		%return;
	%end;
	%LoadGlobalSettingHelper(ids_settings_ds = WORK.tmp_system_setting)
	%&RSUDS.Delete(WORK.tmp_system_setting)

	%&RSULogger.PutNote(Loading configuration dataset name)
	%&DataController.LoadExcel(i_excel_file_path = &G_FILE_SYSTEM_SETTING.
										, i_setting_excel_file_path = &G_FILE_SYSTEM_SETTING.
										, i_sheet_name = Config Files
										, ods_output_ds = WORK.tmp_config_files)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load excel sheet "Config Files" in excel file &G_FILE_SYSTEM_SETTING.)
		%return;
	%end;
	data WORK.tmp_config_files;
		set WORK.tmp_config_files;
		setting_value = cats("&G_CONST_LIB_WORK..", dataset_name);
	run;
	quit;
	%LoadGlobalSettingHelper(ids_settings_ds = WORK.tmp_config_files)
	%&RSUDS.Delete(WORK.tmp_config_files)
%mend LoadGlobalSettings;

%macro LoadGlobalSettingHelper(ids_settings_ds =);
	%local _macro_variable;
	%local _setting_value;
	%local _dsid_global_setting;
	%local _global_setting_info;
	%do %while(%&RSUDS.ForEach(i_query = &ids_settings_ds.
										, i_vars = _macro_variable:macro_variable
													_setting_value:setting_value
										, ovar_dsid = _dsid_global_setting));
		%RSUSetConstant(&_macro_variable., &_setting_value.)
		%&RSUText.Append(iovar_base = _global_setting_info
							, i_append_text = &_macro_variable.:= &_setting_value.
							, i_delimiter = %str(,))
	%end;
	%&RSULogger.PutBlock(&_global_setting_info.)
%mend LoadGlobalSettingHelper;

/**============================================**/
/* ライブラリ解放
/**============================================**/
%macro EnvMgr__DeassignLibraries();
	%&RSUlogger.PutSubsection(Deassining Libraries...)
	%&RSULib.Deassign(&G_CONST_LIB_RSLT.)
	%&RSULib.Deassign(&G_CONST_LIB_HIST.)
	%&RSULib.Deassign(&G_CONST_LIB_WORK.)
	%&RSULib.Deassign(&G_CONST_LIB_VA_DM.)
	%&RSULib.Deassign(&G_CONST_LIB_MODEL_DM.)
	%&VAManager.DeassignLASRLibrary()
%mend EnvMgr__DeassignLibraries;

/**======================================================**/
/* 全入力データのスナップショットを撮る
/*
/* NOTE: ワークフローの先頭で全入力データのスナップショットを作成
/* NOTE: タスクの途中でデータを変えられても不整合が起きないように、以下のタスクでは、スナップショットのデータを使う
/* NOTE: config/AppConfig.xlsx >> resultXX/in/config
/* NOTE: predefined内のxlsx >> resultXX/in/predefined
/* NOTE: staging内のxlsx >> resultXX/in/staging
/**======================================================**/
%macro EnvMgr__TakeSnapshot();
	%&RSULogger.PutSubsection(Preservation of input data)
	%&RSUDir.ClearDir(&G_DIR_USER_DATA_RSLT.
						, i_remove_root = %&RSUBool.False
						, i_is_keep_dir = %&RSUBool.True
						, i_is_recursive = %&RSUBool.True)
	/* config */
	%&RSULogger.PutNote(Taking snapshot of input data in &G_DIR_PROCESS_CONFIG.)
	%&DataController.CopyExcelFiles(i_src_dir = &G_DIR_PROCESS_CONFIG.
											, i_dest_dir = &G_DIR_USER_DATA_RSLT_CONF.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error occured during copying files from &G_DIR_PROCESS_CONFIG. to &G_DIR_USER_DATA_RSLT_CONF.)
		%return;
	%end;
	/* predefined */
	%&RSULogger.PutNote(Taking snapshot of input data in &G_DIR_PREDEFINED_PROCESS.)
	%&DataController.CopyExcelFiles(i_src_dir = &G_DIR_PREDEFINED_PROCESS.
											, i_dest_dir = &G_DIR_USER_DATA_RSLT_DIR2_PREDEF.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error occured during copying files from &G_DIR_PREDEFINED_PROCESS. to &G_DIR_USER_DATA_RSLT_DIR2_PREDEF.)
		%return;
	%end;
	/* staging */
	%&RSULogger.PutNote(Taking snapshot of input data in &G_DIR_USER_DATA_STAGING.)
	%&DataController.CopyExcelFiles(i_src_dir = &G_DIR_USER_DATA_STAGING.
											, i_dest_dir = &G_DIR_USER_DATA_RSLT_DIR1_STG.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error occured during copying files from &G_DIR_USER_DATA_STAGING. to &G_DIR_USER_DATA_RSLT_DIR1_STG.)
		%return;
	%end;
%mend EnvMgr__TakeSnapshot;

/**======================**/
/* Stratum上での実行か否かの判定
/**======================**/
%macro EnvMgr__CheckRunOnStratum();
	%local _result;
	%if (%&RSUUtil.IsMacroVarDefined(G_TCFD_ON_STRATUM_IS_ON_BASESAS)) %then %do;
		%&RSULogger.PutInfo(you are NOT on Stratum)
		%let _result = %&RSUBool.False;
	%end;
	%else %do;
		%&RSULogger.PutInfo(you are on Stratum)
		%let _result = %&RSUBool.True;
	%end;
	&_result.
%mend EnvMgr__CheckRunOnStratum;

/****************** PROPERTIES *************************/
%macro EnvMgr__DSError(i_formula_set_id =);
	&G_CONST_LIB_RSLT..ERR_&i_formula_set_id.
%mend EnvMgr__DSError;

