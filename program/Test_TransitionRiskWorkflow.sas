%rsu_steppingstones_activate_test(i_version = 210)
%&RSUDebug.Disable;
%&RSUFile.IncludeSASCodeIn(i_dir_path = /sas/RSU/RSU_App/TCFD_on_Stratum/program/macros
									, i_is_recursive = %&RSUBool.False)
%RSUSetConstant(G_TCFD_ON_STRATUM_IS_ON_BASESAS, 1)

%macro Workflow__testrun;
	%local /readonly _UI_PROCESS_NAME = TransitionRisk;
	%local /readonly _UI_CYCLE_ID = RUN on BASESAS %&RSUTimer.GetNow;
	%local /readonly _UI_CYCLE_NAME = テスト;
	%local /readonly _UI_USER_ID = sasuser001;
	%local /readonly _UI_KEEP_IN_DM = 1;
	
	%local /readonly _ARRAY_EXEC_CONTROL = %&RSUArray.Create(i_items = 0 1 0 0);

	%local _is_system_prepared;
	%&EnvironmentManager.PrepareProcess(i_user_id = &_UI_USER_ID.
									, i_process_name = &_UI_PROCESS_NAME.
									, ovar_is_system_prepared = _is_system_prepared)
	%if (not &_is_system_prepared.) %then %do;
		%return;
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 1) = 1) %then %do;
		%Workflow__PrepareData(i_cycle_id = &_UI_CYCLE_ID.
										, i_user_id = &_UI_USER_ID.
										, i_process_name = &_UI_PROCESS_NAME.)
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 2) = 1) %then %do;
		%Workflow__RunProcess(i_task_no = 2
									, i_task_title = Financial Projection
									, i_process_id = ProcessFinancialProjection)
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 3) = 1) %then %do;
/*		%Workflow__RunProcess(i_task_no = 3
									, i_task_title = Credit Evaluation
									, i_process_id = ProcessCreditEvalation)*/
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 4) = 1) %then %do;
		%Workflow__Close(i_task_no = 4
								, i_user_id = &_UI_USER_ID.
								, i_cycle_id = &_UI_CYCLE_ID.
								, i_cycle_name = &_UI_CYCLE_NAME.
								, i_keep_in_dm = &_UI_KEEP_IN_DM.)
	%end;
%mend Workflow__testrun;

%Workflow__testrun;