%RSUSetConstant(G_DS_CONFIG, WORK.tmp_config)
%RSUSetConstant(G_DS_APPLICATIONS, WORK.tmp_applications)
%RSUSetConstant(G_DS_USERS, WORK.tmp_users)
%RSUSetConstant(G_DS_DIR_TEMPLATES, WORK.tmp_dir_templates)
%macro LoadConfiguration(i_input_file_path =
								, i_output_file_path =);
	%&RSULogger.PutNote(Loading directory configuration file: &i_input_file_path.)
	%LoadExcel(i_file_path = &i_input_file_path.
					, i_sheet_name = Config
					, ods_output_ds = &G_DS_CONFIG.)
	%LoadExcel(i_file_path = &i_input_file_path.
					, i_sheet_name = Applications
					, ods_output_ds = &G_DS_APPLICATIONS.)
	%LoadExcel(i_file_path = &i_input_file_path.
					, i_sheet_name = Users
					, ods_output_ds = &G_DS_USERS.)
	%LoadExcel(i_file_path = &i_input_file_path.
					, i_sheet_name = Dir Template
					, ods_output_ds = &G_DS_DIR_TEMPLATES.)
	%&RSUFile.WriteLine(i_file_path = &i_output_file_path.
								, i_line = # Directory Configuration Script
								, i_append = %&RSUBool.False)

	%&RSUDebug.PutFootprint;
	%CreateCombinationList(ods_output_combination = WORK.tmp_combination)
	%ProcessDirTemplate(ids_combination = WORK.tmp_combination
							, i_output_file_path = &i_output_file_path.)
	%&RSUDS.Delete(WORK.tmp_combination)
	%&RSUDebug.PutFootprint;
%mend LoadConfiguration;

%macro CreateCombinationList(ods_output_combination =);
	%&RSUDebug.PutFootprint;

	%&RSUDS.GetUniqueList(i_query = &G_DS_APPLICATIONS.
								, i_by_variables = ApplicationID
								, ods_output_ds = WORK.tmp_application_list)
	%&RSUDS.GetUniqueList(i_query = &G_DS_USERS.
								, i_by_variables = UserID
								, ods_output_ds = WORK.tmp_user_list)
	%local /readonly _NO_OF_BACKUP_DIR = %&RSUDS.GetValue(i_query = &G_DS_CONFIG.
																			, i_variable = no_of_backup_dir);
	%local /readonly _FORMAT = %&RSUDS.GetValue(i_query = &G_DS_CONFIG.
															, i_variable = format);
	data WORK.tmp_backup_dir_list(drop = _:);
		do _index = 1 to &_NO_OF_BACKUP_DIR.;
			BackupDir = cats('result', put(_index, &_FORMAT.));
			output;
		end;
	run;
	quit;

	proc sql;
		create table &ods_output_combination.
		as
		select
			tbl_app.*
			, tbl_user.*
			, tbl_bk.*
		from
			WORK.tmp_application_list tbl_app
			, WORK.tmp_user_list tbl_user
			, WORK.tmp_backup_dir_list tbl_bk
		;
	quit;
	%&RSUDS.Delete(WORK.tmp_application_list WORK.tmp_user_list WORK.tmp_backup_dir_list)
	%&RSUDebug.PutFootprint;
%mend CreateCombinationList;

%macro ProcessDirTemplate(ids_combination =
								, i_output_file_path =);
	%local /readonly _ROOT_DIR = %&RSUDS.GetValue(i_query = &G_DS_CONFIG.
																, i_variable = root_dir);
	%local _dir_template;
	%local _owner;
	%local _premission;
	%local _dsid_dir_template;
	%do %while(%&RSUDS.ForEach(i_query = &G_DS_DIR_TEMPLATES.
										, i_vars = _dir_template:dir_template
													_owner:owner
													_premission:permission
										, ovar_dsid = _dsid_dir_template));
		%ProcessDirTemplateHelper(ids_combination = &ids_combination.
										, i_root_dir = &_ROOT_DIR.
										, i_dir_template = &_dir_template.
										, i_owner = &_owner.
										, i_permission = &_premission.
										, i_output_file_path = &i_output_file_path.)
	%end;
%mend ProcessDirTemplate;

%macro ProcessDirTemplateHelper(ids_combination =
										, i_root_dir =
										, i_dir_template =
										, i_owner =
										, i_permission =
										, i_output_file_path =);
	%local _loop_variable;
	%FindLoopVariable(i_dir_template = &i_dir_template.
							, ovar_loop_variable = _loop_variable)
	%if (%&RSUUtil.IsMacroBlank(_loop_variable)) %then %do;
		%MakeShellScriptHelper(i_dir_path = &i_root_dir./&i_dir_template.
									, i_owner = &i_owner.
									, i_permission = &i_permission.
									, i_output_file_path = &i_output_file_path.)
	%end;
	%else %do;
		%&RSULogger.PutNote(Parsing: &i_dir_template.)
		%&RSULogger.PutInfo(Loop Variables: &_loop_variable.)
		%&RSUDS.GetUniqueList(i_query = &ids_combination.
									, i_by_variables = &_loop_variable.
									, ods_output_ds = WORK.tmp_loop)
		%local _dir_path;
		%local _owner_and_group;
		%local _applicatio_id;
		%local _user_id;
		%local _backup_dir;
		%local _dsid_loop;
		%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_loop
											, i_vars = _applicatio_id:ApplicationID
														_user_id:UserID
														_backup_dir:BackupDir
											, ovar_dsid = _dsid_loop));
			%let _dir_path = &i_dir_template.;
			%let _dir_path = %sysfunc(tranwrd(&_dir_path., <ApplicationID>, &_applicatio_id.));
			%let _dir_path = %sysfunc(tranwrd(&_dir_path., <UserID>, &_user_id.));
			%let _dir_path = %sysfunc(tranwrd(&_dir_path., <BackupDir>, &_backup_dir.));
			%let _owner_and_group = &i_owner.;
			%let _owner_and_group = %sysfunc(tranwrd(&_owner_and_group., <UserID>, &_user_id.));
			%MakeShellScriptHelper(i_dir_path = &i_root_dir./&_dir_path.
										, i_owner = &_owner_and_group.
										, i_permission = &i_permission.
										, i_output_file_path = &i_output_file_path.)
		%end;
	%end;
%mend ProcessDirTemplateHelper;

%macro FindLoopVariable(i_dir_template =
								, ovar_loop_variable =);
	%local /readonly _REGEX_LOOP = %&RSURegex.GetIterator(i_regex_expression = /<\w+>/
																			, i_text = &i_dir_template.);
	%let &ovar_loop_variable. =;
	%local _tmp_loop_variable;
	%do %while(%&_REGEX_LOOP.Next);
		%let _tmp_loop_variable = %&RSUText.Mid(i_text = %&_REGEX_LOOP.Current
															, i_pos = 2
															, i_length = %&_REGEX_LOOP.CurrentLen - 2);
		%&RSUText.Append(iovar_base = &ovar_loop_variable.
							, i_append_text = &_tmp_loop_variable.)
	%end;
	%&RSUClass.Dispose(_REGEX_LOOP)
%mend FindLoopVariable;

%macro MakeShellScriptHelper(i_dir_path =
									, i_owner =
									, i_permission =
									, i_output_file_path =);
	%&RSUFile.WriteLine(i_file_path = &i_output_file_path.
								, i_line = mkdir -p &i_dir_path.
								, i_append = %&RSUBool.True)
	%&RSUFile.WriteLine(i_file_path = &i_output_file_path.
								, i_line = chown &i_owner. &i_dir_path.
								, i_append = %&RSUBool.True)
	%&RSUFile.WriteLine(i_file_path = &i_output_file_path.
								, i_line = chmod &i_permission. &i_dir_path.
								, i_append = %&RSUBool.True)
%mend MakeShellScriptHelper;

%macro LoadExcel(i_file_path =
					, i_sheet_name =
					, ods_output_ds =);
	proc import out = &ods_output_ds. datafile = "&i_file_path."
		dbms = xlsx replace;
		sheet = "&i_sheet_name.";
		getnames = yes;
	run;
	quit;
%mend LoadExcel;
