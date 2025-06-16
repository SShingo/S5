/***************************************************/
/* DataController.sas
/*	Written by Shingo Suzuki (shingo.suzuki@sas.com)
/*	RSU, SAS Institute Japan
/*
/*	Roppongi 6−10−1, Roppongi Hills Mori Tower, 11F
/*	Minato-ku, Tokyo, Japan
/*	106-6111
/***************************************************/
%RSUSetConstant(DataObject, DataObj__)

%macro DataObj__DSVariablePart(i_suffix =);
	&G_CONST_LIB_WORK..value_&i_suffix.
%mend DataObj__DSVariablePart;
