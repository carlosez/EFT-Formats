select * from all_tab_columns 
where table_name in ( 'XX_AP_EFT_FORMATS', 'XX_AP_EFT_FORMAT_DEFINITIONS' ,'XX_SV_AP_EPAYMENT_MASTER', 'XX_SV_AP_EPAYMENT_DETAIL' ) 

select FORMAT_ID from XX_AP_EFT_FORMATS;


delete from XX_AP_EFT_FORMATS where FORMAT_NAME = 'Net banking (CITIBANK)';


select distinct DF.PART_OF_FILE from  XX_AP_EFT_FORMAT_DEFINITIONS df
;

delete from XX_AP_EFT_FORMAT_DEFINITIONS df
where df.FORMAT_ID not in (select FORMAT_ID from XX_AP_EFT_FORMATS)
;

select * from XX_AP_EFT_FORMAT_DEFINITIONS;

select 
 null  FORMAT_ID
,ms.FORMAT_NAME   FORMAT_NAME
,decode( MS.TYPE_TEXT_FILE, 'DELIMITED', 'DELIMITED', 'POSITIONS' , 'FIXED_WIDTH')  FORMAT_TYPE
, ascii(decode(MS.DELIMITER,'T',chr(9),MS.DELIMITER)) ACII_DELIMITER
, null
, ms.CREATED_BY
,ms.CREATION_DATE
,ms.LAST_UPDATED_BY
,ms.LAST_UPDATE_DATE
from
XX_SV_AP_EPAYMENT_MASTER ms
where MS.ID_MASTER = nvl(:p_id_master,MS.ID_MASTER )
;


select * 
  from XX_AP_EFT_FORMAT_DEFINITIONS DF
 where DF.FORMAT_ID = 3
;


select 
 dt.ID_FILE_FORMAT  DEFINITION_ID
,dt.ID_MASTER       FORMAT_ID
,dt.FIELD_NAME          FIELD_NAME
,dt.TYPE_VALUE          TYPE_VALUE
, replace(replace(dt.CONSTANT_VALUE,'\E',' '),'\N','')  CONSTANT_VALUE
,dt.SECUENCE    SECUENCE
,dt.START_POSITION  START_POSITION
,dt.END_POSITION  END_POSITION
,dt.DATA_TYPE  DATA_TYPE
,dt.FORMAT  FORMAT_MODEL
,ascii(replace(dt.PADDING_CHARACTER,'E',' ')) PADDING_CHARACTER
,decode(nvl(dt.NEEDS_PADDING,'N'),'Y', dt.DIRECTION_PADDING, 'N','NONE')  DIRECTION_PADDING
,dt.SQL_STATEMENT  SQL_STATEMENT
,decode(dt.PART_OF_FILE, 'TRX','BODY','FOOTER','TRAILER',dt.PART_OF_FILE)  PART_OF_FILE
,dt.CREATED_BY  CREATED_BY
,dt.CREATION_DATE  CREATION_DATE
,dt.LAST_UPDATED_BY  LAST_UPDATED_BY
,dt.LAST_UPDATE_DATE  LAST_UPDATE_DATE
 from XX_SV_AP_EPAYMENT_DETAIL Dt
 where Dt.id_master  = 3
 ;
 
select 
ba.BANK_ACCOUNT_NAME ,  ba.bank_account_num, bu.BANK_ACCOUNT_ID
from 
ce_bank_acct_uses_all bu ,ce_bank_accounts    ba
where bu.BANK_ACCOUNT_ID = ba.BANK_ACCOUNT_ID
   and bu.ORG_ID = 345 --:$PROFILES$.ORG_ID
--   and ba.BANK_ID = :$FLEX$.XXSVLISTBAN
;

select dc.PAYMENT_DOCUMENT_NAME
,dc.PAYMENT_DOCUMENT_ID--, dc.*
from ce_payment_documents dc
 where dc.INTERNAL_BANK_ACCOUNT_ID = 18161 -- :$FLEX$.XXSVLISTBAACCOUNTS
--    and dc.PAYMENT_DOC_CATEGORY = 'EFT PAY'
;



