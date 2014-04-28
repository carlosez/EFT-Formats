
grant all on XX_AP_EFT_FORMATS to apps with grant option;

grant all on XX_AP_EFT_FORMAT_DEFINITIONS to apps with grant option;

grant all on XX_AP_EFT_FORMATS_PKG to apps with grant option;

CREATE SEQUENCE BOLINF.XX_AP_EFT_FORMATS_S
START WITH 1
INCREMENT BY 1
MINVALUE 0
NOCACHE 
NOCYCLE 
NOORDER 
;

CREATE SEQUENCE BOLINF.XX_AP_EFT_FORMAT_DEFINITIONS_S
START WITH 1
INCREMENT BY 1
MINVALUE 0
NOCACHE 
NOCYCLE 
NOORDER 

grant all on XX_AP_EFT_FORMAT_DEFINITIONS_S to apps;

grant all on XX_AP_EFT_FORMATS_S to apps;