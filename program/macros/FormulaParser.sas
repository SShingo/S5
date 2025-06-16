/***********************************************************/
/* FormulaParser.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/*
/* NOTE: 入力データを基にして、Formula をレイヤー展開する
/***********************************************************/
%RSUSetConstant(FormulaParser, FormPsr__)

/*-------------------------------------*/
/* 数式完全展開
/*-------------------------------------*/
%macro FormPsr__ExtendFormula(iods_formula_address =
										, ids_formula_ds =);
	%local /readonly _NO_OF_LAYERS = %&RSUDS.GetCount(&iods_formula_address.);
	%local /readonly _NO_OF_FORMULAS = %&RSUDS.GetCount(&ids_formula_ds.);
	%&RSULogger.PutNote(Extending formula: (Layer) x (Formula))
	data &iods_formula_address.(drop = formula_system_id___ __rc);
		if (_N_ = 0) then do;
			set &ids_formula_ds.;
		end;
		set &iods_formula_address.;
		if (_N_ = 1) then do;
			declare hash hh_filter(dataset: "&ids_formula_ds.", multidata: 'yes');
			__rc = hh_filter.definekey('formula_system_id___');
			__rc = hh_filter.definedata(all: 'yes');
			__rc = hh_filter.definedone();
		end;
		__rc = hh_filter.find();
		if (__rc = 0) then do;
			output;
			__rc = hh_filter.find_next();
			do while(__rc = 0);
				output;
				__rc = hh_filter.find_next();
			end;
		end;
	run;
	quit;
	%local /readonly _NO_OF_TOTAL_FORMULA = %&RSUDS.GetCount(&&iods_formula_address.); 
	%&RSULogger.PutInfo(# of total formulas: &_NO_OF_LAYERS. x &_NO_OF_FORMULAS. = &_NO_OF_TOTAL_FORMULA.)

	%&RSUDS.AddSequenceVariable(i_query = &iods_formula_address.
										, i_sequence_variable_name = formula_index)
%mend FormPsr__ExtendFormula;
