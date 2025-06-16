/******************************************************/
/* VAManager.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/******************************************************/
%RSUSetConstant(VAManager, VAMgr__)

/**===========================================**/
/* LASR サーバーの初期設定
/**===========================================**/
%macro VAMgr__ConfigureLASR(i_process_name =
									, i_user_id =);
	%&RSULogger.PutSubsection(LASR server configuration)

	%local _qv_ds_location;
	%ReplaceProcessAndUserInfo(i_value_template = &G_SETTING_LASR_QV_DS_LOC_TMPL.
										, ovar_macro_var = _qv_ds_location);
	%RSUSetConstant(G_LASR_QV_DS_LOCATION, &G_SETTING_LASR_ROOT./&_qv_ds_location.)
	%local _qv_library_name;
	%ReplaceProcessAndUserInfo(i_value_template = &G_SETTING_LASR_QV_LIB_NAME_TMPL.
										, ovar_macro_var = _qv_library_name);
	%RSUSetConstant(G_LASR_QV_LIBRARY_FULL_NAME, &G_LASR_QV_DS_LOCATION./&_qv_library_name.)

	%local _dm_ds_location;
	%ReplaceProcessAndUserInfo(i_value_template = &G_SETTING_LASR_DM_DS_LOC_TMPL.
											, ovar_macro_var = _dm_ds_location);
	%RSUSetConstant(G_LASR_DM_DS_LOCATION, &G_SETTING_LASR_ROOT./&_dm_ds_location.)
	
	%local _dm_library_name;
	%ReplaceProcessAndUserInfo(i_value_template = &G_SETTING_LASR_DM_LIB_NAME_TMPL.
											, ovar_macro_var = _dm_library_name);
	%RSUSetConstant(G_LASR_DM_LIBRARY_FULL_NAME, &G_LASR_DM_DS_LOCATION./&_dm_library_name.)

	%&RSULogger.PutBlock(Quick-View Data Location: &G_LASR_QV_DS_LOCATION.
								, Quick-View library full name: &G_LASR_QV_LIBRARY_FULL_NAME.
								, Datamart Data Location: &G_LASR_DM_DS_LOCATION.
								, Datamart library full name: &G_LASR_DM_LIBRARY_FULL_NAME.)
%mend VAMgr__ConfigureLASR;

%macro ReplaceProcessAndUserInfo(i_value_template =
											, ovar_macro_var =);
	%local _replaced_macro;
	%let _replaced_macro = &i_value_template.;
	%let _replaced_macro = %sysfunc(tranwrd(&_replaced_macro., <PROCESS_NAME>, &i_process_name.));
	%let _replaced_macro = %sysfunc(tranwrd(&_replaced_macro., <USER_ID>, &i_user_id.));
	%let &ovar_macro_var. = &_replaced_macro.;
%mend ReplaceProcessAndUserInfo;

/**=======================================**/
/* LASR ライブラリ割り当て
/**=======================================**/
%macro VAMgr__AssignLASRLibrary();
	%local _is_library_assigned;
	%AssignLASRLibraryHelper(i_library_name = &G_CONST_LIB_LASR_QV.
										, i_library_full_name = &G_LASR_QV_LIBRARY_FULL_NAME.
										, ovar_is_library_assigned = _is_library_assigned)
	%if (not &_is_library_assigned.) %then %do;
		%&RSUError.Throw(Failed to assign path &G_LASR_QV_LIBRARY_FULL_NAME. to LASR library &G_CONST_LIB_LASR_QV.)
		%return;
	%end;
	%AssignLASRLibraryHelper(i_library_name = &G_CONST_LIB_LASR_DM.
										, i_library_full_name = &G_LASR_DM_LIBRARY_FULL_NAME.
										, ovar_is_library_assigned = _is_library_assigned)
	%if (not &_is_library_assigned.) %then %do;
		%&RSUError.Throw(Failed to assign path &G_LASR_DM_LIBRARY_FULL_NAME. to LASR library &G_CONST_LIB_LASR_DM.)
		%return;
	%end;
%mend VAMgr__AssignLASRLibrary;

%macro AssignLASRLibraryHelper(i_library_name =
										, i_library_full_name =
										, ovar_is_library_assigned =);
	libname &i_library_name. meta library = "&i_library_full_name." metaout = data;
	%if (%&RSULib.IsAssigned(&i_library_name.)) %then %do;
		%&RSULogger.PutInfo(&i_library_name.(&i_library_full_name.).... OK)
		%let &ovar_is_library_assigned. = %&RSUBool.True;
	%end;
	%else %do;
		%&RSULogger.PutInfo(&i_library_full_name..... NG)
		%let &ovar_is_library_assigned. = %&RSUBool.False;
	%end;
%mend AssignLASRLibraryHelper;

/**=======================================**/
/* LASR ライブラリ割り当て解除
/**=======================================**/
%macro VAMgr__DeassignLASRLibrary();
	%&RSULogger.PutNote(Deassigning library of LASR server)
	libname &G_CONST_LIB_LASR_QV. clear;
%mend VAMgr__DeassignLASRLibrary;
