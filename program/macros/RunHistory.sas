/*****************************************************************/
/* RunHistory.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: ヒストリ管理データセット操作
/* NOTE: ヒストリデータ出力
/*****************************************************************/
%RSUSetConstant(RunHistory, RunHist__)

/**================================================**/
/* 初期化
/**================================================**/
%macro RunHist__Prepare();
	%if (not %&RSUDS.Exists(&G_CONST_DS_RUN_HISTORY.)) %then %do;
		%&RSULogger.PutInfo(&G_CONST_DS_RUN_HISTORY. not exists.)
		%&RSULogger.PutNote(Creating &G_CONST_DS_RUN_HISTORY...)
		data &G_CONST_DS_RUN_HISTORY.;
			attrib
				&G_CONST_VAR_RUN_HIST_RUNNING_ID. length = 8.
				&G_CONST_VAR_RUN_HIST_PROGRAM_VER. length = $10.
				&G_CONST_VAR_RUN_HIST_CYCLE_ID. length = $100.
				&G_CONST_VAR_RUN_HIST_CYCLE_NAME. length = $300.
				&G_CONST_VAR_RUN_HIST_USER_ID. length = $32.
				&G_CONST_VAR_RUN_HIST_PROC_TYPE. length = $20.
				&G_CONST_VAR_RUN_HIST_MEMO. length = $500
				&G_CONST_VAR_RUN_HIST_START_TIME. length = 8. format = datetime.
				&G_CONST_VAR_RUN_HIST_END_TIME. length = 8. format = datetime.
				&G_CONST_VAR_RUN_HIST_BACKUP_DIR. length = $10.
			;
			call missing(of _all_);
			stop;
		run;
		quit;
	%end;
%mend RunHist__Prepare;

/**==============================================================================**/
/* 計算履歴にレコード追加
/*
/* NOTE: running_id: 自動採番
/* NOTE: program_version: 自動（グローバルマクロ）
/* NOTE: cycle_id: 付与（primary keyのはず）
/* NOTE: cycle_name: 付与
/* NOTE: user_id: 付与
/* NOTE: memo: 付与
/* NOTE: process_type: 付与
/* NOTE: start_time: 現在時刻を付与
/* NOTE: end_time: null
/* NOTE: backup_dir: running_idから自動付与
/* NOTE: バックアップディレクトリは最新のものだけ残して、古いレコードは削除
/**==============================================================================**/
%macro RunHist__AddNewRecord(i_cycle_id =
									, i_cycle_name =
									, i_user_id =
									, i_process_name =);
	%&RSULogger.PutSubSection(Process of Run history)
	%local /readonly _SETTING_MEMO = %&CalculationSetting.Get(i_key = &G_CONST_VAR_RUN_HIST_MEMO.);
	%local _next_running_id;
	%if (%&RSUDS.IsDSEmpty(&G_CONST_DS_RUN_HISTORY.)) %then %do;
		%let _next_running_id = 1;
	%end;
	%else %do;
		proc sql noprint;
			select
				max(&G_CONST_VAR_RUN_HIST_RUNNING_ID.) + 1 into :_next_running_id trimmed
			from
				&G_CONST_DS_RUN_HISTORY.
			;
		quit;
	%end;
	%local _backup_dir;
	%let _backup_dir = %eval(%sysfunc(mod(&_next_running_id. - 1, &G_SETTING_NO_OF_BACKUP_DIR.)) + 1);
	%let _backup_dir = result%sysfunc(putn(&_backup_dir., &G_SETTING_BK_DIR_SUFFIX_FORMAT.));

	/* バックアップディレクトリ */
	%&RSULogger.PutNote(Clearing backup dir "&_backup_dir."...)
	%&RSUDir.ClearDir(&G_DIR_USER_DATA_HISTORY./&_backup_dir.
							, i_remove_root = %&RSUBool.False
							, i_is_keep_dir = %&RSUBool.True
							, i_is_recursive = %&RSUBool.True)
	/* 記録 */
	/* 古いバックアップディレクトリを記録している履歴を削除 */
	/* レコード追加 */
	%&RSULogger.PutNote(Adding new record in &G_CONST_DS_RUN_HISTORY.)
	%&RSULogger.PutBlock([Execution profile]
								, Program Ver.: &G_CONST_PROGRAM_VERSION.
								, Cycle ID    : &i_cycle_id.
								, Cycle Name  : &i_cycle_name.
								, User ID     : &i_user_id.
								, Memo        : &_SETTING_MEMO.
								, Process Type: &i_process_name.
								, Backup dir  : &_backup_dir.)

	%local /readonly _TMP_DS_NEW_ENTRY = %&RSUDS.GetTempDSName;
	%local _attrib_code_run_history;
	%&RSUDS.GetDSAttributionCode(ids_dataset = &G_CONST_DS_RUN_HISTORY.
										, ovar_attrib_code = _attrib_code_run_history)
	data &_TMP_DS_NEW_ENTRY.;
		attrib
			&_attrib_code_run_history.
		;
		&G_CONST_VAR_RUN_HIST_RUNNING_ID. = &_next_running_id.;
		&G_CONST_VAR_RUN_HIST_CYCLE_ID. = "&i_cycle_id.";
		&G_CONST_VAR_RUN_HIST_USER_ID. = "&i_user_id.";
		&G_CONST_VAR_RUN_HIST_PROGRAM_VER. = "&G_CONST_PROGRAM_VERSION.";
		&G_CONST_VAR_RUN_HIST_PROC_TYPE. = "&i_process_name.";
		&G_CONST_VAR_RUN_HIST_MEMO. = "&_SETTING_MEMO.";
		&G_CONST_VAR_RUN_HIST_START_TIME. = datetime();
		&G_CONST_VAR_RUN_HIST_BACKUP_DIR. = "&_backup_dir.";
	run;
	quit;
	data &G_CONST_DS_RUN_HISTORY.;
		set
			&G_CONST_DS_RUN_HISTORY.(where = (&G_CONST_VAR_RUN_HIST_BACKUP_DIR. ne "&_backup_dir."))
			&_TMP_DS_NEW_ENTRY.
		;
	run;
	quit;
	%&RSUDS.Delete(&_TMP_DS_NEW_ENTRY.)
%mend RunHist__AddNewRecord;

/**================================================**/
/*	計算終了記録
/*
/* NOTE: 終了時刻を付与
/**================================================**/
%macro RunHist__Finish(i_cycle_id =);
	proc sort
			data = &G_CONST_DS_RUN_HISTORY.
			out = WORK.tmp_current_run_entry
		;
		by
			descending &G_CONST_VAR_RUN_HIST_START_TIME.
		;
	run;
	quit;

	%local /readonly _RUNNING_ID = %&RSUDS.GetValue(i_query = WORK.tmp_current_run_entry(where = (&G_CONST_VAR_RUN_HIST_CYCLE_ID. = "&i_cycle_id." and missing(&G_CONST_VAR_RUN_HIST_END_TIME.)) obs = 1)
																	, i_variable = &G_CONST_VAR_RUN_HIST_RUNNING_ID.);
	%if (%&RSUUtil.IsMacroBlank(_RUNNING_ID)) %then %do;
		%&RSULogger.PutWarning(Corresponding run history entry not found. Skipped)
		%return;
	%end;
	%local /readonly _DIR_NAME_BACKUP = %&RSUDS.GetValue(i_query = WORK.tmp_current_run_entry(where = (&G_CONST_VAR_RUN_HIST_RUNNING_ID. = "&_RUNNING_ID."))
																		, i_variable = &G_CONST_VAR_RUN_HIST_BACKUP_DIR.);
	%&RSUDS.Delete(WORK.tmp_current_run_entry)
	%local /readonly _BACKUP_DIR = &G_DIR_USER_DATA_HISTORY./&_DIR_NAME_BACKUP.;
	%&RSULogger.PutNote(Makig backup in "&_BACKUP_DIR.")
	/* config */
	%&DataController.CopyExcelFiles(i_src_dir = &G_DIR_USER_DATA_RSLT_CONF.
											, i_dest_dir = &_BACKUP_DIR./in/config)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error occured during copying files from &G_DIR_USER_DATA_RSLT_CONF. to &_BACKUP_DIR./in/config)
		%return;
	%end;
	/* predefined */
	%&DataController.CopyExcelFiles(i_src_dir = &G_DIR_USER_DATA_RSLT_DIR2_PREDEF.
											, i_dest_dir = &_BACKUP_DIR./in/predefined)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error occured during copying files from &G_DIR_USER_DATA_RSLT_DIR2_PREDEF. to &_BACKUP_DIR./in/predefined)
		%return;
	%end;
	/* staging */
	%&DataController.CopyExcelFiles(i_src_dir = &G_DIR_USER_DATA_RSLT_DIR1_STG.
											, i_dest_dir = &_BACKUP_DIR./in/staging)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Error occured during copying files from &G_DIR_USER_DATA_RSLT_DIR1_STG. to &_BACKUP_DIR./in/staging)
		%return;
	%end;
	/* result */
	%&RSULogger.PutNote(Copying result datasets in result directory to "&_BACKUP_DIR."...)
	%&RSULib.CopyDSInLib(i_libname = &G_CONST_LIB_RSLT.
								, i_dir_path = &_BACKUP_DIR.)

	/* 終了記録 */
	%local _end_time;
	data &G_CONST_DS_RUN_HISTORY.;
		set &G_CONST_DS_RUN_HISTORY.;
		if (&G_CONST_VAR_RUN_HIST_RUNNING_ID. = "&_RUNNING_ID.") then do;
			&G_CONST_VAR_RUN_HIST_END_TIME. = datetime();
			call symputx('_end_time', &G_CONST_VAR_RUN_HIST_END_TIME.);
		end;
	run;
	quit;
	%&RSULogger.PutInfo(End time is recorded in &G_CONST_DS_RUN_HISTORY.(&G_CONST_VAR_RUN_HIST_RUNNING_ID.: &_RUNNING_ID.))
%mend RunHist__Finish;
