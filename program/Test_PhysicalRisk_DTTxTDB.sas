%rsu_steppingstones_activate(i_dir = &G_APP_ROOT_S5./&G_APP_S5_PROGRAM_ROOT_DIR./macros/RSUSteppingStones)
%&RSUDebug.Disable()
%&RSUFile.IncludeSASCodeIn(i_dir_path = &G_APP_ROOT_S5./&G_APP_S5_PROGRAM_ROOT_DIR./macros
									, i_is_recursive = %&RSUBool.False)
%RSUSetConstant(G_TCFD_ON_STRATUM_IS_ON_BASESAS, 1)

data WORK.formula_execution_controller;
	attrib
		is_executed length = 8.
		formula_set_id length = $18.
		simulation_range length = $100.
	;
	infile datalines missover;
	input
		is_executed
		formula_set_id
		simulation_range
	;
datalines;
0 HzImpact Time{ホライズン}>20190331
1 FacilityDmg  Time{ホライズン}>=20190331
0 BSPL 1
0 TDBScore Time{ホライズン}>=20190331
0 PD Time{ホライズン}>=20190331
0 Collateral Time{ホライズン}>=20190331
0 EL Time{ホライズン}>20190331
;
run;
quit;
%macro Workflow__testrun;
	%local /readonly _UI_PROCESS_NAME = PhysicalRisk_DTTxTDB;
	%local /readonly _UI_CYCLE_ID = RUN on BASESAS %&RSUTimer.GetNow;
	%local /readonly _UI_CYCLE_NAME = テスト;
	%local /readonly _UI_USER_ID = &sysuserid;
	%local /readonly _UI_KEEP_IN_DM = 1;
	%local /readonly _UI_FA_ID = rmc.2021.03;
	%local /readonly _UI_HOST = http://jpnvm2011303.jpn.sas.com;
	%local /readonly _UI_PORT = 7980;
	%local /readonly _UI_PASSWORD = Orion123;
	%local /readonly _UI_TGT_TICKET =;

	%local /readonly _ARRAY_EXEC_CONTROL = %&RSUArray.Create(i_items = 1 0 0);

	%&EnvironmentManager.PrepareProcess(i_user_id = &_UI_USER_ID.
													, i_process_name = &_UI_PROCESS_NAME.)
	%if (%&RSUError.Catch()) %then %do;
		%return;
	%end;

	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 1) = 1) %then %do;
		%&WFScenarioSimulation.PrepareData(i_user_id = &_UI_USER_ID.
													, i_process_name = &_UI_PROCESS_NAME.
													, i_fa_id = &_UI_FA_ID.
													, i_host = &_UI_HOST.
													, i_port = &_UI_PORT.
													, i_password = &_UI_PASSWORD.
													, i_cycle_id = &_UI_CYCLE_ID.)
		%if (%&RSUError.Catch()) %then %do;
			%return;
		%end;
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 2) = 1) %then %do;
		%local /readonly _MAIN_TIMER = %&RSUTimer.Create();

		%local _is_executed;
		%local _is_prev_executed;
		%local _formula_set_id;
		%local _simulation_range;
		%local _dsid_formula;
		%do %while(%&RSUDS.ForEach(i_query = WORK.formula_execution_controller
										, i_vars = _is_executed:is_executed
													_formula_set_id:formula_set_id 
													_simulation_range:simulation_range
										, ovar_dsid = _dsid_formula));
			%if (&_is_prev_executed. = 1 and &_is_executed. = 0) %then %do;
					%&RSUDS.TerminateLoop(_dsid_formula);
					%goto _leave_run_simulation_loop;
			%end;
			%if (&_is_executed. = 1) %then %do;
				%ClearEachFormulaDataHelper(i_formula_set_id = &_formula_set_id.)
				%RunEachFormulaInProcess(i_formula_set_id = &_formula_set_id.
												, i_simulation_range = &_simulation_range.)
				%if (%&RSUError.Catch()) %then %do;
					%&RSUDS.TerminateLoop(_dsid_formula)
					%goto _leave_run_simulation_loop;
				%end;
			%end;
			%let _is_prev_executed = &_is_executed.;
		%end;
%_leave_run_simulation_loop:
		%&RSUDS.Delete(WORK.formula_execution_controller)
		%&RSUClass.Dispose(_MAIN_TIMER)
	%end;
	%if (%&RSUArray.Get(_ARRAY_EXEC_CONTROL, i_index = 3) = 1) %then %do;
		%&WFScenarioSimulation.Close(i_user_id = &_UI_USER_ID.
												, i_cycle_id = &_UI_CYCLE_ID.
												, i_cycle_name = &_UI_CYCLE_NAME.
												, i_keep_in_dm = &_UI_KEEP_IN_DM.)
		%if (%&RSUError.Catch()) %then %do;
			%return;
		%end;
	%end;
%mend Workflow__testrun;

%Workflow__testrun