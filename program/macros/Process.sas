/******************************************************/
/* Process.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/******************************************************/
%RSUSetConstant(Process, Process__)

/*------------------------------*/
/* 事前処理
/*------------------------------*/
%macro Process__DoPreprocess();
	%&RSULib.ClearLib(&G_CONST_LIB_WORK.)
	%&RSULib.ClearLib(&G_CONST_LIB_RSLT.)
	%&RSULib.ClearLib(WORK)

	/* スナップショット */
	/* !以後すべてスナップショットファイルから読み出す */
	%&EnvironmentManager.TakeSnapshot()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to take snapshot of input data. Process terminated.)
		%return;
	%end;

	/* 計算設定ファイル読み込み */
	%&CalculationSetting.Load()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load calculation settings. Process terminated.)
		%return;
	%end;

	/* 計算履歴追加 */
	%&RunHistory.AddNewRecord(i_cycle_id = &i_cycle_id.
									, i_user_id = &i_user_id
									, i_process_name = &i_process_name.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to add new entry to RunHistory. Process terminated.)
		%return;
	%end;

	/* 設定データセット読み込み */
	%&ConfigurationTable.Create()
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to create configuration tables. Process terminated.)
		%return;
	%end;
%mend Process__DoPreprocess;