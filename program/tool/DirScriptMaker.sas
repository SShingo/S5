%rsu_steppingstones_activate_test(i_version = 210);
%&RSUDebug.Disable;
%&RSUFile.IncludeSASCodeIn(i_dir_path = &G_APP_ROOT_S5./program/macros
									, i_is_recursive = %&RSUBool.False)

%LoadConfiguration(i_input_file_path = /sas/RSU/RSU_App/S5/program/tool/DirectoryConfig.xlsx
						, i_output_file_path = /tmp/make_dir.sh)
