
grant all on XX_AP_EFT_FORMATS to apps with grant option;

grant all on XX_AP_EFT_FORMAT_DEFINITIONS to apps with grant option;

grant all on XX_AP_EFT_FORMATS_PKG to apps with grant option;

grant all on XX_AP_EFT_FORMATS_UTL to apps with grant option;

grant all on XX_AP_EFT_FORMAT_DEFINITIONS_S to apps;

grant all on XX_AP_EFT_FORMATS_S to apps;

GRANT EXECUTE, READ, WRITE ON DIRECTORY SYS.XX_BANK_ELECTRONIC_DIR TO APPS WITH GRANT OPTION;
/
exit
/