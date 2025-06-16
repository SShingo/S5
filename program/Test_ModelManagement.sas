%rsu_steppingstones_activate(i_dir = &G_APP_ROOT_S5./&G_APP_S5_PROGRAM_ROOT_DIR./macros/RSUSteppingStones)
%&RSUDebug.Disable;
%&RSUFile.IncludeSASCodeIn(i_dir_path = &G_APP_ROOT_S5./&G_APP_S5_PROGRAM_ROOT_DIR./macros
									, i_is_recursive = %&RSUBool.False)
%RSUSetConstant(G_TCFD_ON_STRATUM_IS_ON_BASESAS, 1)

%macro Workflow__testrun;
	%local /readonly _UI_PROCESS_NAME = ModelManagement;
	%local /readonly _UI_CYCLE_ID = RUN on BASESAS %&RSUTimer.GetNow;
	%local /readonly _UI_CYCLE_NAME = Model Management テスト;
	%local /readonly _UI_USER_ID = &sysuserid;
	%local /readonly _UI_KEEP_IN_DM = 1;
	%local /readonly _UI_FA_ID = rmc.2021.03;
	%local /readonly _UI_HOST = http://jpnvm2011303.jpn.sas.com;
	%local /readonly _UI_PORT = 7980;
	%local /readonly _UI_PASSWORD = Orion123;
	%local /readonly _UI_TGT_TICKET =;

	%local /readonly _ARRAY_EXEC_CONTROL = %&RSUArray.Create(i_items = 0 1 0);

	%&EnvironmentManager.PrepareProcess(i_user_id = &_UI_USER_ID.
													, i_process_name = &_UI_PROCESS_NAME.)
	%if (%&RSUError.Catch()) %then %do;
		%return;
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 1) = 1) %then %do;
		%&WFModelManagement.PrepareData(i_cycle_id = &_UI_CYCLE_ID.
												, i_user_id = &_UI_USER_ID.
												, i_process_name = &_UI_PROCESS_NAME.
												, i_fa_id = &_UI_FA_ID.
												, i_host = &_UI_HOST.
												, i_port = &_UI_PORT.
												, i_password = &_UI_PASSWORD.)
		%if (%&RSUError.Catch()) %then %do;
			%return;
		%end;
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 2) = 1) %then %do;
		%local /readonly _TIMER = %&RSUTimer.Create;
		%&Simulator.RunProcess(i_process_id = MODEL_EVALUATION)
		%&ModelManager.StoreResult()
%_leave_run_simulation_loop:
		%&RSUClass.Dispose(_TIMER)
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 3) = 1) %then %do;
		%&WFModelManagement.Close(i_user_id = &_UI_USER_ID.
										, i_cycle_id = &_UI_CYCLE_ID.
										, i_cycle_name = &_UI_CYCLE_NAME.
										, i_action = &_UI_KEEP_IN_DM.)
		%if (%&RSUError.Catch()) %then %do;
			%return;
		%end;
	%end;
%mend Workflow__testrun;

%Workflow__testrun