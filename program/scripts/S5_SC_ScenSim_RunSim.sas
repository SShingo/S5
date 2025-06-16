/* ************************************************** *
 *            Analysis Model Template               *
 * ************************************************** *

 Usage of model parameters.

 Model parameters in the UI cannot contain any special characters, spaces or underscore.
 The case is insensitive when defining the parameter, however the name of the parameter must be all uppercase when using the below syntax to retrieve the value.

  - Numeric, String or Single-Selection prompts
      If you have a parameter named MyParameter, you can retrieve its value using the syntax:

         %let my_parameter = ${params.MYPARAMETER}

  - Multi-Selection prompts
      If you have a parameter named MyMultiSelect, you can retrieve the selected values using the syntax:

         %let my_multi_select = ${params.MYMULTISELECT}

      The values are returned as a JSON array i.e.
         my_multi_select ->   [value1, value2, ..., valueN]

      You can convert this array structure into a space separated list by using the following regular expression:

         * Get rid of square backets and commas *
         %let my_multi_select = %sysfunc(prxchange(s/[\[%str(,)\]]//i, -1, %superq(my_multi_select)));

  - Objects (single-selection): Analysis Data, RuleSet, DataMap, Business Evolution plan, etc.
      If you have a parameter named MyObject, you can retrieve any of the attributes defined with the object using the syntax:

         %let my_object_<attribute> = ${params.MYOBJECT.attribute}

         Examples:
            * Retrieve the object key *
            %let my_object_key = ${params.MYOBJECT.key}

            * Retrieve the object name *
            %let my_object_key = ${params.MYOBJECT.name}


   - Objects (multi-selection): Analysis Data, RuleSet, DataMap, Business Evolution plan, etc.

      If you have a parameter named BEP you can use the following syntax to generate a number of macro variables that contain the selected object keys
      ${function:ProcessModelParameter(params.BEP, "BEP")}

      For details about this function, please consult the groovy function documentation section under the Administration tab of the web application.


 * ************************************************** */
/* User Id */
%global /readonly user_id = ${context.cycle.currentUserId};

/* Cycle Key */
%global cycle_id;
%let cycle_id = ${context.cycle.key};

/* Process Name */
%global process_name;
%let process_name = ${context.cycle.processName};
%let process_name = %scan(&process_name., 4, '_');

%global current_wokflow_status;
%let current_wokflow_status = ${context.cycle.currentStatusCd};

/* Cycle Name */
%global /readonly cycle_name = %nrbquote(${context.cycle.name});

/* RGF Connection parameters */
%global /readonly rgf_protocol = ${globals.protocol};
%global /readonly rgf_host = ${globals.host};
%global /readonly rgf_port = ${globals.port};
%global /readonly rgf_service = ${globals.service};
%global /readonly rgf_solution = ${globals.contentId};

/* Get the root location of the SAS Risk Workgroup Application */
%global /readonly sas_risk_workgroup_dir = ${globals.sas_risk_workgroup_dir};

/* TGT Authentication Ticket */
%global rgf_tgt_ticket;
%let rgf_tgt_ticket = ${globals.ticket};

/* Analysis Run Id */
%global analysis_run_id;
%let analysis_run_id = ${context.analysisRun.key};

/* Entity Id */
%global entity_id;
%let entity_id = ${context.cycle.entityId};

/* Federated Area Id */
%global /readonly irm_fa_id = ${context.cycle.versionNm};

/* Stratum Federated Area Id */
%global rmc_fa_id;
%let rmc_fa_id = ${context.cycle.rmcVersionNm};

/* Base Date/Datetime (format: yyyy-MM-dd or yyyy-MM-dd hh:mm:ss) */
%global base_dt;
%let base_dt = ${context.cycle.baseDt};

/* IRM Configuration Set Id */
/* ! 未使用 */
%global config_set_id;
%let config_set_id = ${params.CONFIGSETID};

%global program_root_dir;
%global /readonly program_version = ${params.PROGRAMVERSION};
%if (%sysevalf(%superq(program_version) =, boolean)) %then %do;
	%let program_root_dir = &G_APP_ROOT_S5./program;
%end;
%else %do;
	%let program_root_dir = &G_APP_ROOT_S5./&program_version.;
%end;
%rsu_steppingstones_activate(i_dir = &program_root_dir./macros/RSUSteppingStones)
%&RSUDebug.Disable
options validvarname = any;

%&RSUFile.IncludeSASCodeIn(i_dir_path = &program_root_dir./macros
									, i_is_recursive = %&RSUBool.False)
%global _is_system_prepared;
%&EnvironmentManager.PrepareProcess(i_user_id = &user_id.
												, i_process_name = &process_name.
												, ovar_is_system_prepared = _is_system_prepared)
%if (&_is_system_prepared.) %then %do;
	%&WFScenarioSimulation.RunProcess(i_workflow_status = &current_wokflow_status.)
%end;
%else %do;
	%&RSULogger.PutError(Failed to prepare the system. Execution cancelled.)
%end;