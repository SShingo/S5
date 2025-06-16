/***************************************************/
/*	ResultDatamart.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/***************************************************/
%RSUSetConstant(ResultDatamart, ResultDM__)

/**===========================================**/
/* DMにデータをアペンド
/*
/* NOTE: ユーザーをまたいだ総合DMを作成
/**===========================================**/
%macro ResultDM__AppendResult(i_user_id =
										, i_cycle_id =
										, i_cycle_name =);
	%local _dm_key;
	%let _dm_key = (&i_user_id.);
	%&RSUText.Append(iovar_base = _dm_key
							, i_append_text = (&i_cycle_id). 
							, i_delimiter = -)
	%&RSUText.Append(iovar_base = _dm_key
							, i_append_text = %&RSUTimer.GetNow
							, i_delimiter = -)
	%local /readonly _RESULT_DS_LIST = %&RSULib.GetDSInLib(&G_CONST_LIB_RSLT.);
	%local _ds_result;
	%local _index_ds_result;
	%local _ds_result_name;
	%do %while(%&RSUUtil.ForEach(i_items = &_RESULT_DS_LIST.
										, ovar_item = _ds_result
										, iovar_index = _index_ds_result));
		%&RSULogger.PutNote(Accumulating result dataset "&_ds_result." to VM datamart.)
		data WORK.tmp_result;
			set &G_CONST_LIB_RSLT..&_ds_result.;
			attrib
				&G_CONST_VAR_DM_DM_KEY. length = $500.
				&G_CONST_VAR_DM_USER_ID. length = $200.
				&G_CONST_VAR_DM_CYCLE_ID. length = $200.
				&G_CONST_VAR_DM_CYCLE_NAME length = $200.
				&G_CONST_VAR_DM_REG_DATETIME. length = 8. format = datetime.
			;
			&G_CONST_VAR_DM_DM_KEY. = "&_dm_key.";
			&G_CONST_VAR_DM_USER_ID. = "&i_user_id.";
			&G_CONST_VAR_DM_CYCLE_ID. = "&i_cycle_id.";
			&G_CONST_VAR_DM_CYCLE_NAME. = "&i_cycle_name.";
			&G_CONST_VAR_DM_REG_DATETIME. = datetime();
		run;
		quit;

		%let _ds_result_name = %&RSUDS.GetDSName(&G_CONST_LIB_RSLT..&_ds_result.);
		%&RSUDS.Append(iods_base_ds = %DSVADM(i_result_ds_name = &_ds_result_name.)
							, ids_data_ds = WORK.tmp_result)
		%DeleteOldDataInDM(iods_dm_dataset = %DSVADM(i_result_ds_name = &_ds_result_name.)
								, i_today = %sysfunc(today())
								, i_life_time_in_month = &G_SETTING_DM_LIFETIME_MONTH.)
		%&RSUDS.Delete(WORK.tmp_result)
	%end;
%mend ResultDM__AppendResult;

%macro DeleteOldDataInDM(iods_dm_dataset =
								, i_today =
								, i_life_time_in_month = );
	%local /readonly _OLDEST_DAY = %sysfunc(intnx(month, &i_today, -&i_life_time_in_month., same));
	%&RSULogger.PutNote(Deleting data in DM which are older than %&RSUDAte.SASDate2YYYYMMDDs(&_OLDEST_DAY.))
	%&RSUDS.Let(i_query = &iods_dm_dataset.(where = (&_OLDEST_DAY. <= datepart(&G_CONST_VAR_DM_REG_DATETIME.)))
					, ods_dest_ds = &iods_dm_dataset.)
%mend DeleteOldDataInDM;

%macro DSVADM(i_result_ds_name =);
	&G_CONST_LIB_VA_DM..va_dm_&i_result_ds_name.
%mend DSVADM;