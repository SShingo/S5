/******************************************************/
/* ModelManger.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/******************************************************/
%RSUSetConstant(ModelManager, MdlMgr__)
%RSUSetConstant(G_DS_MODEL_DM, L_MDLDM.model)

/**===========================**/
/* Model DM 初期化
/**===========================**/
%macro MdlMgr__InitializeDM();
	%&RSULogger.PutSubsection(Model datamart)
	%if (not %&RSUDS.Exists(&G_CONST_DS_MODEL_DATAMART.)) %then %do;
		%&RSULogger.PutNote(Generate Model DM newly)
		data &G_CONST_DS_MODEL_DATAMART.;
			attrib
				model_id length = $100.
				model_version length = $100.
				model_definiion_new length = $3000.
				registered_by length = $100.
				registered_time length = 8. format = datetime.
			;
			stop;
		run;
		quit;
	%end;

	%&RSULogger.PutInfo(Model DM contains %&RSUDS.GetCount(&G_CONST_DS_MODEL_DATAMART.) model(s))
%mend MdlMgr__InitializeDM;

/**===================================**/
/* モデルDS作成
/*
/* NOTE: Molde DMから抽出
/* NOTE: Predefined, Stagingから読み込み
/* NOTE: DM < Predefined < Stagingの順
/**===================================**/
%macro MdlMgr__CreateDSFromDMAndExcel(ids_formula_definition =
												, ids_model_list =
												, ods_model_definition =);
	%&RSULogger.PutSubsection(Model definition from datamart)
	%&RSUDS.Delete(&ods_model_definition.)
	%GetModelDefintionFromDM(ids_used_model_list = &ids_model_list.
									, ods_raw_model = WORK.tmp_model_definition)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to extract model from datamart)
		%return;
	%end;

	%MdlMgr__LoadModelFromExcel(iods_model_definition = WORK.tmp_model_definition
										, ods_output_ds = &ods_model_definition.)
	%if (%&RSUError.Catch()) %then %do;
		%&RSUError.Throw(Failed to load models from excel
		%return;
	%end;
%mend MdlMgr__CreateDSFromDMAndExcel;

%macro MdlMgr__LoadModelFromExcel(iods_model_definition =
											, ods_output_ds =);
	%&RSULogger.PutNote(Loading model definition form Excel file)
	%local _directory;
	%local _index_directory;

	%do %while(%&RSUUtil.ForEach(i_items = &G_DIR_USER_DATA_RSLT_DIR2_PREDEF. &G_DIR_USER_DATA_RSLT_DIR1_STG.
										, ovar_item = _directory
										, iovar_index = _index_directory));
		%LoadModelDefinition(i_direcory_path = &_directory.
									, iods_model_definition = &iods_model_definition.)
		%if (%&RSUError.Catch()) %then %do;
			%&RSUError.Throw(Failed to load model from Excel
			%return;
		%end;
	%end;
	%&RSUDS.Move(i_query = &iods_model_definition.
					, ods_dest_ds = &ods_output_ds.)
%mend MdlMgr__LoadModelFromExcel;

/**===================================**/
/* Formula定義からモデルを取り出す
/**===================================**/
%macro MdlMgr__ExtractModelsInFormula(ids_formula_definition =
												, ods_model_list =);
	%&RSULogger.PutSubsection(Models in formula)
	%&RSULogger.PutNote(Finding model reference in formula definition)
	%&RSUDS.Delete(&ods_model_list.)

	%local /readonly _REGEX_MODEL_REF = (&G_CONST_REGEX_VPR_FUNC_DELM.)(&G_CONST_REGEX_MODEL_REF.);
	%local /readonly _TMP_DS_MODELS_USED_IN_FORM = %&RSUDS.GetTempDSName(models_in_formula);
	data &_TMP_DS_MODELS_USED_IN_FORM.(keep =  model_id);
		set &ids_formula_definition.;
		attrib
			model_id length = $300.
			__tmp_decmp_definition length = $3000.
		;
		__tmp_decmp_regex_model = prxparse("/&_REGEX_MODEL_REF./o");
		__tmp_decmp_definition = catt('`', strip(formula_definition_rhs), '`');
		__tmp_decmp_org_length = lengthn(__tmp_decmp_definition);
		__tmp_decmp_start = 1;
		__tmp_decmp_stop = __tmp_decmp_org_length;
		__tmp_decmp_position = 1;
		__tmp_decmp_length = 0;

		call prxnext(__tmp_decmp_regex_model, __tmp_decmp_start, __tmp_decmp_stop, __tmp_decmp_definition, __tmp_decmp_position, __tmp_decmp_length);
		do while(0 < __tmp_decmp_position);
			model_id = prxposn(__tmp_decmp_regex_model, &G_CONST_VPR_FUNC_POS_VAR_REF. + 2, __tmp_decmp_definition);
			output;
			call prxnext(__tmp_decmp_regex_model, __tmp_decmp_start, __tmp_decmp_stop, __tmp_decmp_definition, __tmp_decmp_position, __tmp_decmp_length);
		end;
	run;
	quit;

	%if (%&RSUDS.IsDSEmpty(&_TMP_DS_MODELS_USED_IN_FORM.)) %then %do;
		%&RSUDS.Delete(&_TMP_DS_MODELS_USED_IN_FORM.)
		%&RSULogger.PutInfo(No model found in formula definition)
		%return;
	%end;

	%&RSUDS.GetUniqueList(i_query = &_TMP_DS_MODELS_USED_IN_FORM.
								, i_by_variables = model_id
								, ods_output_ds = &ods_model_list.)
	/* Profile */
	%local _model_list;
	proc sql noprint;
		select
			model_id into :_model_list separated by '&RSUComma.'
		from
			&ods_model_list.
		;
	quit;
	%&RSULogger.PutBlock([Models in formula]
								, &_model_list.)
	%&RSUDS.Delete(&_TMP_DS_MODELS_USED_IN_FORM.)
%mend MdlMgr__ExtractModelsInFormula;

/*------------------------------------------------------------------*/
/* RSMからモデル抽出
/*
/* NOTE: Formulaに定義されている "Model{***}"を取り出してリスト作成
/* NOTE: DMから定義を取り出す → L_WORK.data_model として保存
/*------------------------------------------------------------------*/
%macro GetModelDefintionFromDM(ids_used_model_list =
										, ods_raw_model =);
	%&RSULogger.PutNote(Extracting model definition from  DM)
	data WORK.tmp_model_dm;
		set &G_CONST_DS_MODEL_DATAMART.;
		model_id = catx(';', model_id, model_version);
	run;
	quit;
	%&RSUDS.LeftJoin(ids_lhs_ds = &ids_used_model_list.
						, ids_rhs_ds = WORK.tmp_model_dm
						, i_conditions = model_id:model_id
						, ods_output_ds = WORK.tmp_model_definition_from_dm)
	%&RSUDS.Delete(WORK.tmp_model_dm)
	%local _model_id;
	%local _model_definition;
	%local _dsid_model_def;
	%local _model_status;
	%do %while(%&RSUDS.ForEach(i_query = WORK.tmp_model_definition_from_dm
										, i_vars = _model_id:model_id
													_model_definition:model_definition
										, ovar_dsid = _dsid_model_def));
		%let _model_status = %&RSUUtil.Choose(%&RSUUtil.IsMacroBlank(_model_definition), Not found, Found);
		%&RSULogger.PutInfo(&_model_id....&_model_status.)								
	%end;
	/* profile */
	%&RSUDS.Move(i_query = WORK.tmp_model_definition_from_dm(where = (not missing(model_definition)) keep = model_id model_definition)
					, ods_dest_ds = &ods_raw_model)
%mend GetModelDefintionFromDM;

%macro GetModelDefintionFromDMHelper(ids_used_model_list =
												, ods_output_ds =);
	data WORK.tmp_model_dm;
		set &G_CONST_DS_MODEL_DATAMART.;
		model_id = catx(';', model_id, model_version);
	run;
	quit;

	data &ods_output_ds.(keep = model_id model_definition);
		set &ids_models_in_dm.;
		if (_N_ = 1) then do;
			declare hash hh_model(dataset: 'WORK.tmp_model_dm');
			_rc = hh_model.definekey('model_id');
			_rc = hh_model.definedone();
		end;
		_rc = hh_model.find();
		if (_rc = 0) then do;
			output;
		end;
	run;
	quit;
	%&RSUDS.Delete(WORK.tmp_model_dm)
%mend GetModelDefintionFromDMHelper; 

/*--------------------------------------------------------*/
/* Model 定義Excel
/*
/* NOTE: ファイル名、シート名はグローバルマクロに設定済み
/* NOTE: モデルファイルは1つしかない（例: モデル!定義）
/*--------------------------------------------------------*/
%macro LoadModelDefinition(i_direcory_path =
									, iods_model_definition =);
	%local /readonly _EXCEL_FILE_PATH = &i_direcory_path./&G_SETTING_MODEL_DEF_FILE_NAME..xlsx;
	%local /readonly _EXCEL_SHEET_NAME = &G_SETTING_MODEL_DEF_SHEET_NAME.;

	%if (not %&RSUFile.Exists(&_EXCEL_FILE_PATH.)) %then %do;
		%&RSULogger.PutInfo(Excel file &_EXCEL_FILE_PATH. not found)
		%goto _leave_load_model_definition;
	%end;
	%if (not %&RSUExcel.ContainsSheet(i_file_path = &_EXCEL_FILE_PATH., i_sheet_name = &_EXCEL_SHEET_NAME.)) %then %do;
		%&RSULogger.PutInfo(Excel sheet "&_EXCEL_SHEET_NAME." not found in &_EXCEL_FILE_PATH.)
		%goto _leave_load_model_definition;
	%end;
	%&RSULogger.PutInfo(Model definition file found)

	/* 読み込み */
	%&DataController.LoadExcel(i_excel_file_path = &_EXCEL_FILE_PATH.
										, i_setting_excel_file_path = &G_FILE_SYSTEM_SETTING.
										, i_schema_name = &G_CONST_SHCEMA_TYPE_MODEL.
										, i_sheet_name = &_EXCEL_SHEET_NAME.
										, ods_output_ds = WORK.tmp_unit_loaded_data)
	%if (%&RSUError.Catch()) %then %do;
		%return;
	%end;
	data WORK.tmp_unit_loaded_data(drop = model_version);
		set WORK.tmp_unit_loaded_data;
		model_id = catx(';', model_id, model_version);
	run;
	quit;
	/* Overwrite */
	%&DataController.Overwrite(iods_base_ds = &iods_model_definition.
										, ids_data_ds = WORK.tmp_unit_loaded_data
										, i_by_variables = model_id)
	%&RSUDS.Delete(WORK.tmp_unit_loaded_data)
%_leave_load_model_definition:
%mend LoadModelDefinition;

/**====================================**/
/* モデル更新アクションテーブル
/**====================================**/
%macro MdlMgr__MakeMdlUpdateActionTbl(i_cycle_id =
												, i_cycle_name =
												, i_user_id =);
	data &G_CONST_DS_MODEL_UPDATE.(keep = model_id model_version model_definiion_new registered_by_new);
		attrib
			model_id length = $100.
			model_version length = $100.
			model_definiion_new length = $3000.
			registered_by_new length = $100.
		;
		set &G_CONST_DS_FORMULA_DEFINITION.;
		model_id = scan(&G_CONST_VAR_VARIABLE_REF_NAME., 1, ';');
		model_version = scan(&G_CONST_VAR_VARIABLE_REF_NAME., 2, ';');
		model_definiion_new = formula_definition_rhs;
		registered_by_new = "&i_user_id.";
	run;
	quit;

	proc sort data = &G_CONST_DS_MODEL_UPDATE.;
		by
			model_id
			model_version
		;
	run;
	quit;

	proc sort data = &G_CONST_DS_MODEL_DATAMART.;
		by
			model_id
			model_version
		;
	run;
	quit;

	data &G_CONST_DS_MODEL_UPDATE.;
		attrib
			action length = $3.
		;
		merge
			&G_CONST_DS_MODEL_DATAMART.(in = in1)
			&G_CONST_DS_MODEL_UPDATE.(in = in2)
		;
		by
			model_id
			model_version
		;
		if (not in2) then do;
			action = '';
		end;
		else do;
			if (in1) then do;
				if (missing(model_definiion_new)) then do;
					action = 'DEL';
				end;
				else if (compress(model_definiion) = compress(model_definiion_new)) then do;
					action = 'SKP';
				end;
				else do;
					action = 'MOD';
				end;
			end;
			else do;
				action = 'ADD';
			end;
		end;
	run;
	quit;

	%&LASRUpldr.Upload(i_library_full_name = &G_LASR_QV_LIBRARY_FULL_NAME.
							, i_lasr_library = &G_CONST_LIB_LASR_QV.
							, ids_source_ds = &G_CONST_DS_MODEL_UPDATE.
							, i_dest_location = &G_LASR_QV_DS_LOCATION.
							, i_is_append = %&RSUBool.False)

	%&LASRUpldr.Upload(i_library_full_name = &G_LASR_DM_LIBRARY_FULL_NAME.
							, i_lasr_library = &G_CONST_LIB_LASR_DM.
							, ids_source_ds = &G_CONST_DS_MODEL_DATAMART.
							, i_dest_location = &G_LASR_DM_DS_LOCATION.
							, i_is_append = %&RSUBool.False)
%mend MdlMgr__MakeMdlUpdateActionTbl;

/**================================================**/
/* DMに登録
/**================================================**/
%macro MdlMgr__AppendToDM(i_overwrite =);
	%local _no_of_as_is;
	%local _no_of_modified;
	%local _no_of_deleted;
	%local _no_of_added;

	%local /readonly _NO_OF_MODELS_BEFORE = %&RSUDS.GetCount(&G_CONST_DS_MODEL_DATAMART.);
	%if (&i_overwrite.) %then %do;
		%&RSULogger.PutNote(Register models to datamart(Overwrite mode))
		data &G_CONST_DS_MODEL_DATAMART.;
			set &G_CONST_DS_MODEL_UPDATE. end = eof;
			retain _no_of_as_is 0;
			retain _no_of_modified 0;
			retain _no_of_deleted 0;
			retain _no_of_added 0;
			if (action = 'DEL') then do;
				_no_of_deleted = _no_of_deleted + 1;
				delete;
			end;
			else if (action = 'MOD') then do;
				_no_of_modified = _no_of_modified + 1;
				model_definiion = model_definiion_new;
				registered_by = registered_by_new;
				registered_time = datetime();
				output;
			end;
			else if (action = 'ADD') then do;
				_no_of_added = _no_of_added + 1;
				model_definiion = model_definiion_new;
				registered_by = registered_by_new;
				registered_time = datetime();
				output;
			end;
			else do;
				_no_of_as_is = _no_of_as_is + 1;
				output;
			end;
			if (eof) then do;
				call symputx('_no_of_as_is', _no_of_as_is);
				call symputx('_no_of_modified', _no_of_modified);
				call symputx('_no_of_deleted', _no_of_deleted);
				call symputx('_no_of_added', _no_of_added);
			end;
			keep 
				model_id
				model_version
				model_definiion
				registered_by
				registered_time
			;
		run;
		quit;
	%end;
	%else %do;
		%&RSULogger.PutNote(Register models to datamart(Append only mode))
		data &G_CONST_DS_MODEL_DATAMART.;
			set &G_CONST_DS_MODEL_UPDATE. end = eof;
			retain _no_of_as_is 0;
			retain _no_of_modified 0;
			retain _no_of_deleted 0;
			retain _no_of_added 0;
			if (action = 'ADD') then do;
				_no_of_added = _no_of_added + 1;
				model_definiion = model_definiion_new;
				registered_by = registered_by_new;
				registered_time = datetime();
				output;
			end;
			else do;
				_no_of_as_is = _no_of_as_is + 1;
				output;
			end;
			if (eof) then do;
				call symputx('_no_of_as_is', _no_of_as_is);
				call symputx('_no_of_modified', _no_of_modified);
				call symputx('_no_of_deleted', _no_of_deleted);
				call symputx('_no_of_added', _no_of_added);
			end;
			keep 
				model_id
				model_version
				model_definiion
				registered_by
				registered_time
			;
		run;
		quit;
	%end;
	%local /readonly _NO_OF_MODELS_AFTER = %&RSUDS.GetCount(&G_CONST_DS_MODEL_DATAMART.);
	%&RSULogger.PutBlock([Model DM update profile]
								, # of unchanged model: &_no_of_as_is.
								, # of modified model: &_no_of_modified.
								, # of added model: &_no_of_added
								, # of deleted model: &_no_of_deleted.
								, Total # of models: &_NO_OF_MODELS_BEFORE. >> &_NO_OF_MODELS_AFTER.)
	%&LASRUpldr.Upload(i_library_full_name = &G_LASR_DM_LIBRARY_FULL_NAME.
							, i_lasr_library = &G_CONST_LIB_LASR_DM.
							, ids_source_ds = &G_CONST_DS_MODEL_DATAMART.
							, i_dest_location = &G_LASR_DM_DS_LOCATION.
							, i_is_append = %&RSUBool.False)
%mend MdlMgr__AppendToDM;

/**=========================**/
/* モデル実行結果をアップロード
/**=========================**/
%macro MdlMgr__StoreResult();
	%&LASRUpldr.Upload(i_library_full_name = &G_LASR_QV_LIBRARY_FULL_NAME.
							, i_lasr_library = &G_CONST_LIB_LASR_QV.
							, ids_source_ds = %&FormulaManager.FormulaResult(i_formula_set_id = MODEL_EVALUATION)
							, i_dest_location = &G_LASR_QV_DS_LOCATION.
							, i_is_append = %&RSUBool.False)
%mend MdlMgr__StoreResult;