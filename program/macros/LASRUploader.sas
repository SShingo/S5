/******************************************************/
/* LASRUpldr.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/******************************************************/
%RSUSetConstant(LASRUpldr, LASRUpldr__)

/**===================================================**/
/* データアップロード & Meta 登録
/**===================================================**/
%macro LASRUpldr__Upload(i_library_full_name =
								, i_lasr_library =
								, ids_source_ds =
								, i_dest_location =
								, i_is_append =);
	%&RSULogger.PutNote(Uploading and registering dataset to LASR Server)
	%&RSULogger.PutBlock(Dataset: &ids_source_ds.
								, LASR Library full name: &i_library_full_name.
								, Location: &i_dest_location.)
	%UploadTable(ids_uploading_ds = &ids_source_ds.
					, i_lasr_library = &i_lasr_library.
					, i_is_append = &i_is_append.)
	%RegisterTable(i_location_path = &i_dest_location.
						, ids_registering_ds = &ids_source_ds.
						, i_library_full_name = &i_library_full_name.)
%mend LASRUpldr__Upload;

%macro UploadTable(ids_uploading_ds =
						, i_lasr_library =
						, i_is_append =);
	%&RSULogger.PutNote(Uploading data "&ids_uploading_ds." to LASR library.)
	%local /readonly _UPLOADING_DS_NAME = %&RSUDS.GetDSName(&ids_uploading_ds.);
	%if (not &i_is_append.) %then %do;
		%&RSUDS.Delete(&i_lasr_library..&_UPLOADING_DS_NAME.)
	%end;
	%local /readonly _APPEND_OPTION = %&RSUUtil.Choose(&i_is_append., yes, no);
	data &i_lasr_library..&_UPLOADING_DS_NAME.(append = &_APPEND_OPTION.);
		set &ids_uploading_ds.;
	run;
	quit;
%mend UploadTable;

%macro RegisterTable(i_location_path =
							, ids_registering_ds =
							, i_library_full_name =);
	%local /readonly _UPLOADING_DS_NAME = %&RSUDS.GetDSName(&ids_registering_ds.);
	%&RSULogger.PutNote(Registering &i_location_path./&_UPLOADING_DS_NAME. to &i_library_full_name. library.)
	proc metalib;
		omr (library = "&i_library_full_name."); 
		folder = "&i_location_path.";
		select ("&_UPLOADING_DS_NAME."); 
	run; 
	quit;
%mend RegisterTable;
