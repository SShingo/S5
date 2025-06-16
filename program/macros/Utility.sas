/***************************************************/
/*	Utility.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/***************************************************/
%RSUSetConstant(Utility, Utility__)

%macro Utility__SaveDS(ids_source_ds =
							, i_save_as =
							, i_keep_original = %&RSUBool.False);
	%local /readonly _DS_SIZE = %&RSUDS.GetCount(&ids_source_ds.);
	%if (&i_keep_original.) %then %do;
		%&RSUDS.Let(i_query = &ids_source_ds.
						, ods_dest_ds = &i_save_as.)
	%end;
	%else %do;
		%&RSUDS.Move(i_query = &ids_source_ds.
						, ods_dest_ds = &i_save_as.)
	%end;
	%&RSULogger.PutNote(&i_save_as. saved (&_DS_SIZE. observation(s)))
%mend Utility__SaveDS;

%macro Utility__ShowDSSingleColumn(ids_source_ds =
											, i_variable_def =
											, i_title =);
	%local _ds_elements;
	proc sql noprint;
		select
			&i_variable_def into :_ds_elements separated by ','
		from
			&ids_source_ds.
		;
	quit;

	%&RSULogger.PutBlock(&i_title.
								, &_ds_elements.)
%mend Utility__ShowDSSingleColumn;
