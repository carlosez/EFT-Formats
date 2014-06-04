drop public synonym XX_AP_EFT_FORMATS;

drop public synonym XX_AP_EFT_FORMAT_DEFINITIONS;

drop public synonym XX_AP_EFT_FORMATS_S;

drop public synonym XX_AP_EFT_FORMAT_DEFINITIONS_S;

drop public synonym XX_AP_EFT_FORMATS_PKG;

drop public synonym XX_AP_EFT_FORMATS_UTL ;

DROP TABLE BOLINF.XX_AP_EFT_FORMATS;

DROP TABLE BOLINF.XX_AP_EFT_FORMAT_DEFINITIONS;

drop package XX_AP_EFT_FORMATS_PKG;

drop package XX_AP_EFT_FORMATS_UTL;

drop sequence XX_AP_EFT_FORMAT_DEFINITIONS_S;

drop sequence XX_AP_EFT_FORMATS_S;


--select * from   DBA_OBJECTS
--where object_name =  'XX_AP_EFT_FORMATS_S'

--rm $XBOL_TOP/bin/XX_EFT_MOVE_FILE.prog
--rm $XBOL_TOP/bin/XX_EFT_MOVE_FILE

--CREATE OR REPLACE DIRECTORY 
--XX_BANK_ELECTRONIC_DIR AS 
--'/interface/j_mili/DMILII/outgoing/ALL/BANK'
--;
