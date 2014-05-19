--CURSOR c_checks return t_checks IS

  SELECT DESCRIPTIVE_FLEX_CONTEXT_CODE,
         DESCRIPTIVE_FLEX_CONTEXT_NAME,
         DESCRIPTION,
         ENABLED_FLAG,
         APPLICATION_ID,
         DESCRIPTIVE_FLEXFIELD_NAME,
         LAST_UPDATE_DATE,
         LAST_UPDATED_BY,
         LAST_UPDATE_LOGIN,
         CREATION_DATE,
         CREATED_BY,
         GLOBAL_FLAG,
         ROW_ID
    FROM FND_DESCR_FLEX_CONTEXTS_VL dfc
   WHERE 1=1
         and (dfc.APPLICATION_ID = 200)
         AND (dfc.DESCRIPTIVE_FLEXFIELD_NAME = 'AP_CHECKS')
ORDER BY DECODE (global_flag, 'Y', 1, 2), descriptive_flex_context_code;


  SELECT END_USER_COLUMN_NAME,
         DESCRIPTION,
         ENABLED_FLAG,
         APPLICATION_COLUMN_NAME,
         COLUMN_SEQ_NUM,
         DISPLAY_FLAG,
         DEFAULT_VALUE,
         RUNTIME_PROPERTY_FUNCTION,
         REQUIRED_FLAG,
         SECURITY_ENABLED_FLAG,
         DISPLAY_SIZE,
         MAXIMUM_DESCRIPTION_LEN,
         CONCATENATION_DESCRIPTION_LEN,
         FORM_ABOVE_PROMPT,
         FORM_LEFT_PROMPT,
         APPLICATION_ID,
         DESCRIPTIVE_FLEXFIELD_NAME,
         DESCRIPTIVE_FLEX_CONTEXT_CODE,
         RANGE_CODE,
         LAST_UPDATE_DATE,
         LAST_UPDATED_BY,
         LAST_UPDATE_LOGIN,
         CREATED_BY,
         CREATION_DATE,
         FLEX_VALUE_SET_ID,
         DEFAULT_TYPE,
         SRW_PARAM,
         ROW_ID
    FROM FND_DESCR_FLEX_COL_USAGE_VL dfcu
   WHERE 1=1
         and (dfcu.APPLICATION_ID = 200)
         AND (dfcu.DESCRIPTIVE_FLEXFIELD_NAME LIKE 'AP_CHECKS')
         AND (dfcu.DESCRIPTIVE_FLEX_CONTEXT_CODE = 'EL SALVADOR')
ORDER BY column_seq_num



SELECT CH.CHECK_ID
      ,CH.DOC_SEQUENCE_VALUE
      ,ch.check_number
      ,CH.AMOUNT
      ,CH.CHECK_DATE
      ,CH.VENDOR_NAME
      ,status.FLEX_VALUE_MEANING SEND_STATUS
      ,SS.VENDOR_SITE_CODE
      ,APPLICATION_COLUMN_NAME
  FROM APPS.AP_CHECKS_ALL CH
      ,APPS.AP_SUPPLIER_SITES_ALL SS
      ,apps.AP_CHECKS_ALL_DFV chdfv
      ,FND_DESCR_FLEX_COL_USAGE_VL dfcu
      ,FND_DESCR_FLEX_CONTEXTS_VL dfc
      ,(select fvs.flex_value_set_name 
            ,fv.FLEX_VALUE
            ,fvt.FLEX_VALUE_MEANING
        from apps.fnd_flex_value_sets fvs
            ,apps.fnd_flex_values fv
            ,apps.fnd_flex_values_tl fvt
        where  fvs.flex_value_set_name = 'XX_EFT_STATUS_CHECK'
             and  fvs.FLEX_VALUE_SET_ID= fv.FLEX_VALUE_SET_ID
        and fvt.flex_value_id = fv.flex_value_id
        and LANGUAGE = userenv('lang')
        ) status
 WHERE CH.VENDOR_SITE_ID = SS.VENDOR_SITE_ID
   AND CH.PAYMENT_DOCUMENT_ID = :g_PAY_DOCUMENT
   AND TRUNC(CH.CHECK_DATE) >= TRUNC(:g_START_DATE)
   AND TRUNC(CH.CHECK_DATE) <= TRUNC(:g_END_DATE  )
   AND CH.CHECK_NUMBER >= NVL(:g_DOC_INI,CH.CHECK_NUMBER)
   AND CH.CHECK_NUMBER <= NVL(:g_DOC_FIN,CH.CHECK_NUMBER)
   AND CH.AMOUNT between NVL(:g_BASE_AMOUNT ,CH.AMOUNT)
   and NVL(:g_TOP_AMOUNT  ,CH.AMOUNT)
   and status.FLEX_VALUE = nvl(CHDFV.eft_status,'NEW')
   and ch.rowid = chdfv.rowid
   and (dfcu.APPLICATION_ID = 200)
    AND (dfcu.DESCRIPTIVE_FLEXFIELD_NAME LIKE 'AP_CHECKS')
    AND (dfcu.DESCRIPTIVE_FLEX_CONTEXT_CODE = chdfv.country )
    and dfc.DESCRIPTIVE_FLEX_CONTEXT_CODE = chdfv.country
    and (dfc.APPLICATION_ID = 200)
    AND (dfc.DESCRIPTIVE_FLEXFIELD_NAME = 'AP_CHECKS')
    and dfcu.END_USER_COLUMN_NAME =  'EFT_STATUS'
   --AND NVL(CH.ATTRIBUTE14,k_NEW) in ( k_new, g_STATUS_CHECK )
   AND CH.VOID_DATE IS NULL;
   
   


select * from all_directories