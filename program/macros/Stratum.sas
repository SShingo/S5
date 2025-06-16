/********************************************************/
/* Stratum.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/********************************************************/
%RSUSetConstant(Stratum, Stratum__)

/**===============================================**/
/* Stratumの使用準備
/*
/* NOTE: 各タスクの先頭（セッションの先頭）で実行
/*
/* ! コーディング規約に従ってないのが気に入らない
/**===============================================**/
%macro Stratum__ConfigureStratumSystem();
	%&RSULogger.PutSubsection(SAS(R) Stratum(R) system configuration)
	%if (%&EnvironmentManager.CheckRunOnStratum()) %then %do;
		%&RSULogger.PutSubsection(Configuring global macro variables and library to use Stratum functions)
		/***** parameter setting *****/
		/* ********************************************* */
		/* Content specific parameters                   */
		/* ********************************************* */
		%global /readonly solutionId = RMC;
		%global /readonly solutionShortName = Risk Stratum Core;
		%global /readonly solutionName = SAS Risk Stratum Core;
		%global /readonly solutionLibrefPrefix = RMC;
		/* ********************************************* */
		/* Get the location to the IRM Federated Area */
		%global irm_fa_path;
		%let irm_fa_path = %sysfunc(metadata_appprop(IRM Mid-Tier Server, com.sas.solutions.risk.irm.fa.&irm_fa_id.));
		%global rmc_fa_path;
		%let rmc_fa_path = %sysfunc(metadata_appprop(IRM Mid-Tier Server, com.sas.solutions.risk.irm.fa.&rmc_fa_id.));

		/* Set SASAUTOS */
		option insert = (
			SASAUTOS = (
				"&irm_fa_path./source/sas/ucmacros"
				"&rmc_fa_path./source/sas/ucmacros"
				)
			);

		/* Convert Base date/datetime to IRM expected format (MMddyyyy or MMddyyyyhhmmss) */
		%global /readonly irm_base_dt = %sysfunc(prxchange(s/(\d{4})-(\d{2})-(\d{2})[Z]?([ T](\d{2}):(\d{2}):(\d{2})[Z]?)?/$2$3$1$5$6$7/i, -1, &base_dt.));

		/* Set the Cycle directory: the file init.sas will be created in this directory */
		%global /readonly cycle_dir = &sas_risk_workgroup_dir./groups/Public/SASRiskManagementCore/cycles/&cycle_id.;
		/* Create Cycle directory */
		%rsk_mkdirs_and_verify(&cycle_dir.);

		/* Data Repository Libref */
		%global dr_libref;
		%let dr_libref = %upcase(&solutionId.)DR;
		/* Data Repository Metadata Library Name */
		%global /readonly dr_library_name = SAS &solutionShortName. Data Repository;
		/* Assign Data Repository Library */
		libname &dr_libref. meta liburi = "SASLibrary?@Name='&dr_library_name.'" metaout = data;

		/* Reportmart Libref */
		%global /readonly mart_libref = %upcase(&solutionLibrefPrefix.)MART;
		/* Reportmart Metadata Library Name */
		%global mart_library_name;
		%let mart_library_name = SAS &solutionShortName. Reportmart;

		/* SAS Risk Management Core Libref */
		%global /readonly rmc_libref = RGFRMC;
		/* SAS Risk Management Core Metadata Library Name */
		%global /readonly rmc_library_name = SAS Risk Management Core Database;
		/* Initialize the Cycle control table */
		%irmc_update_ctrl_table(cycle_id = &cycle_id., dr_libref = &dr_libref.);

		/* Get current LUAPATH */
		%local /readonly existing_lua = %sysfunc(prxchange(s/[()]//, -1, %sysget(SASLUA)));
		/* Set LUAPATH */
		filename LUAPATH ("&irm_fa_path./source/lua" "&rmc_fa_path./source/lua" &existing_lua.);

		/* Get the connection details for the IRM Server */
		%irm_get_service_info(SWCName = IRM Mid-Tier Server
									, DeployedComponentName = Registered SAS Application
									, ds_out = irm_info
									);

		/* Load connection details into macro variables */
		%global irm_protocol;
		%global irm_host;
		%global irm_port;
		data _null_;
			set irm_info;
			call symputx("irm_protocol", protocol, "G");
			call symputx("irm_host", host, "G");
			call symputx("irm_port", port, "G");
		run;

		/* Get the connection details for the VA Server */
		%irm_get_service_info(SWCName = Visual Analytics Transport Service
									, DeployedComponentName = Registered SAS Application
									, ds_out = va_info
									, exact_match = N
									);

		%global va_protocol;
		%global va_host;
		%global va_port;
		/* Load connection details into macro variables */
		data _null_;
			set va_info;
			call symputx("va_protocol", protocol, "G");
			call symputx("va_host", host, "G");
			call symputx("va_port", port, "G");
		run;


		/* Set the Java classpath macro variable */
		%irm_get_java_classpath(path = &irm_fa_path./source/java/lib/pdfUtils.jar
										, outvar = classpath
										, update_flg = N
										);
		/* Resolve the META libname statement into the actual SASIOLA libname statement */
		%local lasr_libname_stmt;
		%irm_get_libdebug(libname_stmt = libname rmclasr meta liburi = "SASLibrary?@Name='SAS &solutionShortName. LASR'" metaout = data
								, outvar = lasr_libname_stmt
								);
		/* Extract the libref from the libname statement */
		%global /readonly lasr_libref = %scan(%superq(lasr_libname_stmt), 2, %str( ));

		/*********** 以下 init.sas ***************/
		/* Metadata Repository */
		/* ! 未使用 */
		%global /readonly meta_repository = Foundation;

		/* &solutionShortName. LASR Metadata Library Name */
		%global lasr_library_name;
		%let lasr_library_name = SAS &solutionShortName. LASR;

		/* Metadata folder for the LASR tables */
		%global lasr_meta_folder;
		%let lasr_meta_folder = /Products/&solutionName./Data/Visual Analytics;

		options ibufsize = 32760;

		/* Set compress option */
		options compress = binary;

		/* Enable direct execution of sql statement using database engine (for DB libraries) */
		options dbidirectexec;

		/* &solutionShortName. LASR */
		%sysfunc(prxchange(s/["]/"/i, -1, %superq(lasr_libname_stmt)))

		/* SAS Risk Management Core Database */
		libname &rmc_libref. meta liburi = "SASLibrary?@Name='&rmc_library_name.'" metaout = data;
	%end;
%mend Stratum__ConfigureStratumSystem;

/**======================================**/
/* Excel レポートをサイクルにアタッチ
/**======================================**/
%macro Stratum__AttachExcelReport(i_excel_reports =);
	%&RSULogger.PutNote(Attaching excel reports "&i_excel_reports."...)
	%if (%&EnvironmentManager.CheckRunOnStratum()) %then %do;
		%&RSULogger.PutSubsection(Attaching excel report(s).)
		%local _excel_report;
		%local _index_excel_report;
		%do %while(%&RSUUtil.ForEach(i_items = &i_excel_reports.
											, ovar_item = _excel_report
											, iovar_index = _index_excel_report));
			%AttachFileHlper(i_attached_file_name = &_excel_report.)
		%end;
	%end;
	%else %do;
		%&RSULogger.PutInfo(Attaching excel report skipped.)
	%end;
%mend Stratum__AttachExcelReport;

%macro AttachFileHlper(i_attached_file_name =);
	%local _attachment_status;
	%local _rgf_st_ticket;
	%local _httpSuccess;
	%local _response_status;
	%irm_rest_create_rgf_attachment(host = &rgf_protocol.://&rgf_host.
												, server = &rgf_service.
												, solution = &rgf_solution.
												, port = &rgf_port.
												, tgt_ticket = &rgf_tgt_ticket.
												, object_key = &cycle_id.
												, object_type = cycles
												, group_no = 30
												, file = &G_DIR_USER_DATA_RSLT./&i_attached_file_name.
												, attachmentName = &i_attached_file_name.
												, outds = _attachment_status
												, outVarTicket = _rgf_st_ticket
												, outSuccess = _httpSuccess
												, outResponseStatus = _response_status
												)
	%&RSULogger.PutInfo(&G_DIR_USER_DATA_RSLT./&i_attached_file_name. has been attached to the cycle "&cycle_id.".)
%mend AttachFileHlper;

/**===============================**/
/* サイクル Description をアップデート
/* 
/* ! 未使用
/**===============================**/
%macro Stratum__UpdataCycleDesc(i_cycle_id =);
	%if (%&EnvironmentManager.CheckRunOnStratum()) %then %do;
		%local /readonly _SETTING_MEMO = %&CalculationSetting.Get(i_key = memo);
		%&RSULogger.PutNote(Updating description of cycle "&i_cycle_id". Mode: "&_SETTING_MEMO.")
		/* SAS Risk Management Core Database */
		libname &rmc_libref. meta liburi = "SASLibrary?@Name='&rmc_library_name.'" metaout = data;
		proc sql noprint;
			update RGFRMC.cust_obj_214_l set cust_obj_desc = "&_SETTING_MEMO." where cust_obj_214_rk = &i_cycle_id.;
		quit;
	%end;
%mend Stratum__UpdataCycleDesc;

/**===================================**/
/* ワークフロー > プロセス情報
/*
/* ! 未使用
/**===================================**/
%macro Stratum__GetProcessInfo(i_status_cd =
										, ovar_process_id =
										, ovar_process_title =);
	%let &ovar_process_id. = %&RSUDS.GetValue(i_query = &G_SETTING_CONFIG_DS_STRATUM_WF.(where = (workflow_status = "&i_status_cd."))
															, i_variable = process_id);
	%let &ovar_process_title. = %&RSUDS.GetValue(i_query = &G_SETTING_CONFIG_DS_STRATUM_WF.(where = (workflow_status = "&i_status_cd."))
															, i_variable = process_title);
%mend Stratum__GetProcessInfo;