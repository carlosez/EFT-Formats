CREATE OR REPLACE PACKAGE BODY BOLINF.XX_SV_EPAYMENT
IS

FUNCTION XX_GET_INVOICE_NUM (P_INVOICE_ID NUMBER) RETURN VARCHAR2 IS
INVOICE VARCHAR2(50);
BEGIN
SELECT INVOICE_NUM
  INTO INVOICE
  FROM APPS.AP_INVOICES_ALL
 WHERE INVOICE_ID = P_INVOICE_ID;
--+
RETURN(INVOICE);
--+
EXCEPTION
WHEN OTHERS THEN
     RETURN(-1);
END XX_GET_INVOICE_NUM;

FUNCTION XX_GET_INVOICES (P_CHECK_ID NUMBER) RETURN VARCHAR2 IS
   OUT_INVOICES VARCHAR2(500);
   CURSOR INVOICES IS
   SELECT --DISTINCT
          INVOICE_ID
     FROM APPS.AP_INVOICE_PAYMENTS_ALL
    WHERE CHECK_ID = P_CHECK_ID;
BEGIN
   OUT_INVOICES := 'DOCUMENTOS: ';
   FOR V IN INVOICES
   LOOP
   OUT_INVOICES := OUT_INVOICES || XX_GET_INVOICE_NUM(V.INVOICE_ID)||' ';
   END LOOP;

   RETURN(OUT_INVOICES);
   --+
EXCEPTION
WHEN OTHERS THEN
     RETURN(-1);
END XX_GET_INVOICES;


PROCEDURE XX_CREATE_BANK_FILE (ERRBUF     OUT  VARCHAR2,
                               RETCODE    OUT  VARCHAR2,
                               BANK_USED         NUMBER,
                               P_START_DATE    VARCHAR2,
                               P_END_DATE      VARCHAR2) IS

CURSOR INFO IS
SELECT  CH.AMOUNT                CHK_AMOUNT
       ,CH.CHECK_DATE            CHK_DATE
       ,SUP.BANK_ACCOUNT_NAME    BANK_ACC_NAME
       ,SUP.BANK_ACCOUNT_NUM     BANK_ACC_NUMBER
       ,CH.CHECK_ID              CHK_ID
  FROM apps.AP_CHECKS_ALL CH,
  (
       SELECT  distinct
            EBA.BANK_ACCOUNT_NAME
           ,EBA.BANK_ACCOUNT_NUM
           ,HPS.PARTY_SITE_NAME
           ,HZP.PARTY_NAME
           ,APS.VENDOR_ID
      FROM  apps.IBY_EXT_BANK_ACCOUNTS    EBA
           ,apps.IBY_ACCOUNT_OWNERS       IAO
           ,apps.HZ_PARTY_SITES           HPS
           ,apps.AP_SUPPLIERS             APS
           ,apps.HZ_PARTIES               HZP
     WHERE  EBA.EXT_BANK_ACCOUNT_ID    =  IAO.EXT_BANK_ACCOUNT_ID
       AND  IAO.ACCOUNT_OWNER_PARTY_ID =  HPS.PARTY_ID
       AND  HPS.PARTY_ID    =  HZP.PARTY_ID
       AND  APS.PARTY_ID    =  HZP.PARTY_ID
  ) SUP
 WHERE 1=1
   AND CH.CHECK_DATE >= TO_DATE(P_START_DATE,'YYYY/MM/DD HH24:MI:SS')
   AND CH.CHECK_DATE <= TO_DATE(P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS')
   AND CH.CE_BANK_ACCT_USE_ID = BANK_USED
   AND PAYMENT_METHOD_CODE = 'EFT'
   AND CH.VENDOR_ID = SUP.VENDOR_ID
   AND CH.VOID_DATE IS NULL;

LINE       VARCHAR2(1000);
--BKTY       VARCHAR(20);
BEGIN


    FOR X IN INFO
    LOOP

    LINE := REPLACE(X.BANK_ACC_NUMBER,'-','') ||';'
         || REPLACE(X.BANK_ACC_NAME,';',',') || ';'
         ||';'
         || X.CHK_AMOUNT||';'
         || TO_CHAR(X.CHK_DATE,'DDMMYYYY') || ';'
         || REPLACE(XX_GET_INVOICES(X.CHK_ID),';',',');

    fnd_file.PUT_LINE(fnd_file.OUTPUT,LINE);

    END LOOP;
    retcode := '0';

EXCEPTION
     WHEN OTHERS
     THEN
  retcode := '2';
  errbuf := SQLERRM;
 ROLLBACK;

 END XX_CREATE_BANK_FILE;
 
PROCEDURE XX_UPDATE_PROCESS_CHECKS(PARMETERS IN REPORT_PARAMETER) IS

BEGIN
    BEGIN
        IF PARMETERS.CHECKRUN_ID IS NOT NULL THEN
        UPDATE AP_CHECKS_ALL CH
           SET CH.ATTRIBUTE14 = 'PRINTED'
         WHERE 1=1
           AND CH.PAYMENT_DOCUMENT_ID = PARMETERS.PAY_DOCUMENT
           AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(PARMETERS.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
           AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(PARMETERS.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
           AND CH.CHECKRUN_ID = PARMETERS.CHECKRUN_ID
           AND CH.AMOUNT >= NVL(PARMETERS.BASE_AMOUNT ,CH.AMOUNT)
           AND CH.AMOUNT <= NVL(PARMETERS.TOP_AMOUNT  ,CH.AMOUNT)
           AND PAYMENT_METHOD_CODE = 'EFT'
           AND CH.VOID_DATE IS NULL;
       
        ELSE
            
        UPDATE AP_CHECKS_ALL CH
           SET CH.ATTRIBUTE14 = 'PRINTED'
         WHERE 1=1
           AND CH.PAYMENT_DOCUMENT_ID = PARMETERS.PAY_DOCUMENT
           AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(PARMETERS.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
           AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(PARMETERS.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
           AND CH.DOC_SEQUENCE_VALUE >= NVL(PARMETERS.P_DOC_INI,CH.DOC_SEQUENCE_VALUE)
           AND CH.DOC_SEQUENCE_VALUE <= NVL(PARMETERS.P_DOC_FIN,CH.DOC_SEQUENCE_VALUE)
           AND CH.AMOUNT >= NVL(PARMETERS.BASE_AMOUNT ,CH.AMOUNT)
           AND CH.AMOUNT <= NVL(PARMETERS.TOP_AMOUNT  ,CH.AMOUNT)
           AND PAYMENT_METHOD_CODE = 'EFT'
           AND CH.VOID_DATE IS NULL;
        END IF;
        COMMIT;
    EXCEPTION
    WHEN OTHERS THEN 
    ROLLBACK;
    END;
    
END XX_UPDATE_PROCESS_CHECKS;
 
 /*
    ############################################################
        FUNCION XX_LOG_REPORT_DETAILS 
    ############################################################
 */

PROCEDURE XX_GET_TRXAMOUNT_AND_TRXLINES (PARMETERS IN  REPORT_PARAMETER
                                       ,V         IN OUT RUNTIME_VALUES) IS

BEGIN 
    IF PARMETERS.CHECKRUN_ID IS NOT NULL THEN
    SELECT SUM(CH.AMOUNT), COUNT(CH.AMOUNT)
      INTO V.SUM_TRANS   , V.TRX_LINES
      FROM AP_CHECKS_ALL CH
     WHERE 1=1
       AND CH.PAYMENT_DOCUMENT_ID = PARMETERS.PAY_DOCUMENT
       AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(PARMETERS.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
       AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(PARMETERS.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
       AND CH.AMOUNT >= NVL(PARMETERS.BASE_AMOUNT ,CH.AMOUNT)
       AND CH.AMOUNT <= NVL(PARMETERS.TOP_AMOUNT  ,CH.AMOUNT)
       AND CH.CHECKRUN_ID = PARMETERS.CHECKRUN_ID
       AND PAYMENT_METHOD_CODE = 'EFT'
       AND NVL(CH.ATTRIBUTE14,'NEW') = 'NEW'
       AND CH.VOID_DATE IS NULL;
    ELSE
        
    SELECT SUM(CH.AMOUNT), COUNT(CH.AMOUNT)
      INTO V.SUM_TRANS   , V.TRX_LINES
      FROM AP_CHECKS_ALL CH
     WHERE 1=1
       AND CH.PAYMENT_DOCUMENT_ID = PARMETERS.PAY_DOCUMENT
       AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(PARMETERS.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
       AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(PARMETERS.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
       AND CH.DOC_SEQUENCE_VALUE >= NVL(PARMETERS.P_DOC_INI,CH.DOC_SEQUENCE_VALUE)
       AND CH.DOC_SEQUENCE_VALUE <= NVL(PARMETERS.P_DOC_FIN,CH.DOC_SEQUENCE_VALUE)
       AND CH.AMOUNT >= NVL(PARMETERS.BASE_AMOUNT ,CH.AMOUNT)
       AND CH.AMOUNT <= NVL(PARMETERS.TOP_AMOUNT  ,CH.AMOUNT)
       AND PAYMENT_METHOD_CODE = 'EFT'
       AND NVL(CH.ATTRIBUTE14,'NEW') = 'NEW'
       AND CH.VOID_DATE IS NULL;
    END IF;
                                   
END XX_GET_TRXAMOUNT_AND_TRXLINES;                                   

PROCEDURE XX_GET_TRX_INVOICES  (PARMETERS IN  REPORT_PARAMETER
                               ,V         IN OUT RUNTIME_VALUES) IS
BEGIN
    IF PARMETERS.CHECKRUN_ID IS NOT NULL THEN
    SELECT COUNT(IPA.INVOICE_ID)
      INTO V.REPORT_LINES
      FROM AP_CHECKS_ALL CH
          ,AP_INVOICE_PAYMENTS_ALL IPA
     WHERE 1=1
       AND CH.PAYMENT_DOCUMENT_ID = PARMETERS.PAY_DOCUMENT
       AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(PARMETERS.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
       AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(PARMETERS.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
       AND CH.AMOUNT >= NVL(PARMETERS.BASE_AMOUNT ,CH.AMOUNT)
       AND CH.AMOUNT <= NVL(PARMETERS.TOP_AMOUNT  ,CH.AMOUNT)
       AND CH.CHECKRUN_ID = PARMETERS.CHECKRUN_ID
       AND PAYMENT_METHOD_CODE = 'EFT'
       AND NVL(CH.ATTRIBUTE14,'NEW') = 'NEW'
       AND CH.VOID_DATE IS NULL;
       
       V.REPORT_LINES := V.REPORT_LINES + V.TRX_LINES;
    ELSE
        
    SELECT COUNT(IPA.INVOICE_ID)
      INTO V.REPORT_LINES
      FROM AP_CHECKS_ALL CH
          ,AP_INVOICE_PAYMENTS_ALL IPA
     WHERE 1=1
       AND CH.PAYMENT_DOCUMENT_ID = PARMETERS.PAY_DOCUMENT
       AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(PARMETERS.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
       AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(PARMETERS.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
       AND CH.DOC_SEQUENCE_VALUE >= NVL(PARMETERS.P_DOC_INI,CH.DOC_SEQUENCE_VALUE)
       AND CH.DOC_SEQUENCE_VALUE <= NVL(PARMETERS.P_DOC_FIN,CH.DOC_SEQUENCE_VALUE)
       AND CH.AMOUNT >= NVL(PARMETERS.BASE_AMOUNT ,CH.AMOUNT)
       AND CH.AMOUNT <= NVL(PARMETERS.TOP_AMOUNT  ,CH.AMOUNT)
       AND PAYMENT_METHOD_CODE = 'EFT'
       AND NVL(CH.ATTRIBUTE14,'NEW') = 'NEW'
       AND CH.VOID_DATE IS NULL;
       V.REPORT_LINES := V.REPORT_LINES + V.TRX_LINES;
    END IF;
END XX_GET_TRX_INVOICES;

PROCEDURE XX_GET_SUMARY_VALUES (P IN  REPORT_PARAMETER
                               ,V IN OUT RUNTIME_VALUES) IS
                               

BEGIN

    XX_GET_TRX_INVOICES (P,V);
    XX_GET_TRXAMOUNT_AND_TRXLINES(P,V);

END XX_GET_SUMARY_VALUES;
 
 
procedure  XX_LOG_REPORT_DETAILS ( PARAMETERS_P REPORT_PARAMETER ) IS
          
V_BANK_NAME       VARCHAR2(400);
V_BRANCH_NAME     VARCHAR2(400);
V_PAYMENT_DOC     VARCHAR2(400);
V_BANK_ACC_NAME   VARCHAR2(400);
V_BATCH_NAME      VARCHAR2(400);
V_TRX_COUNTER        NUMBER;
V_SUM_OF_TRX         NUMBER;
LINE              VARCHAR2(500);

SUMARY_V         RUNTIME_VALUES;

CURSOR CHECKS_SPECIFIC(P REPORT_PARAMETER) IS
SELECT CH.CHECK_ID
      ,CH.DOC_SEQUENCE_VALUE
      ,CH.AMOUNT
      ,CH.CHECK_DATE
      ,CH.VENDOR_NAME
      ,lk2.displayed_field CHECK_STATUS 
      ,CH.ATTRIBUTE14 SEND_STATUS
      ,SS.VENDOR_SITE_CODE
  FROM APPS.AP_CHECKS_ALL CH
      ,APPS.ap_lookup_codes lk2
      ,AP_SUPPLIER_SITES_ALL SS
 WHERE 1=1
   AND CH.VENDOR_SITE_ID = SS.VENDOR_SITE_ID
   AND CH.PAYMENT_DOCUMENT_ID = P.PAY_DOCUMENT
   AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(P.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
   AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(P.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
   AND CH.DOC_SEQUENCE_VALUE >= NVL(P.P_DOC_INI,CH.DOC_SEQUENCE_VALUE)
   AND CH.DOC_SEQUENCE_VALUE <= NVL(P.P_DOC_FIN,CH.DOC_SEQUENCE_VALUE)
   AND CH.AMOUNT >= NVL(P.BASE_AMOUNT ,CH.AMOUNT)
   AND CH.AMOUNT <= NVL(P.TOP_AMOUNT  ,CH.AMOUNT)
   AND PAYMENT_METHOD_CODE = 'EFT'
   AND NVL(CH.ATTRIBUTE14,'NEW') = 'NEW'
   and lk2.lookup_type = 'CHECK STATE'
   and lk2.lookup_code = ch.status_lookup_code
   AND CH.VOID_DATE IS NULL;
   

CURSOR CHECKS_BATCH(P REPORT_PARAMETER) IS
SELECT CH.CHECK_ID
      ,CH.DOC_SEQUENCE_VALUE
      ,CH.AMOUNT
      ,CH.CHECK_DATE
      ,CH.VENDOR_NAME
      ,SS.VENDOR_SITE_CODE
      ,LK2.DISPLAYED_FIELD CHECK_STATUS 
      ,CH.ATTRIBUTE14 SEND_STATUS
  FROM AP_CHECKS_ALL CH
      ,AP_SUPPLIER_SITES_ALL SS
      ,APPS.AP_LOOKUP_CODES LK2
 WHERE 1=1
   AND CH.VENDOR_SITE_ID = SS.VENDOR_SITE_ID
   AND CH.PAYMENT_DOCUMENT_ID = P.PAY_DOCUMENT
   AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(P.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
   AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(P.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
   AND CH.AMOUNT >= NVL(P.BASE_AMOUNT ,CH.AMOUNT)
   AND CH.AMOUNT <= NVL(P.TOP_AMOUNT  ,CH.AMOUNT)
   AND CH.CHECKRUN_ID = P.CHECKRUN_ID
   AND PAYMENT_METHOD_CODE = 'EFT'
   AND NVL(CH.ATTRIBUTE14,'NEW') = 'NEW'
   AND LK2.LOOKUP_TYPE = 'CHECK STATE'
   AND LK2.LOOKUP_CODE = CH.STATUS_LOOKUP_CODE
   AND CH.VOID_DATE IS NULL;

begin 

    XX_GET_SUMARY_VALUES (PARAMETERS_P,SUMARY_V );
    fnd_file.PUT_LINE(fnd_file.LOG,'+---------------------------------------------------------------------------+');
    fnd_file.PUT_LINE(fnd_file.LOG,'Begin Log Summary Values ');
    fnd_file.PUT_LINE(fnd_file.LOG,'+---------------------------------------------------------------------------+');
    
    BEGIN
    select b.BANK_NAME
    INTO V_BANK_NAME 
    FROM ce_banks_v b
    where b.BANK_PARTY_ID = PARAMETERS_P.BANK_ID;
    
    select ba.BANK_ACCOUNT_NAME
      INTO V_BANK_ACC_NAME 
      from ce_bank_accounts      ba
     where ba.BANK_ACCOUNT_ID = PARAMETERS_P.BANK_ACC;
    
    select dc.PAYMENT_DOCUMENT_NAME
      INTO V_PAYMENT_DOC
      FROM ce_payment_documents dc
     where dc.PAYMENT_DOCUMENT_ID = PARAMETERS_P.PAY_DOCUMENT;
        
        IF PARAMETERS_P.CHECKRUN_ID IS NOT NULL THEN
        SELECT CH.CHECKRUN_NAME
          INTO V_BATCH_NAME
          FROM AP_CHECKS_ALL CH
         WHERE CH.CHECKRUN_ID = PARAMETERS_P.CHECKRUN_ID
           AND CH.PAYMENT_TYPE_FLAG = 'A'
           AND CH.ROWID = ( SELECT MAX(ROWID) FROM AP_CHECKS_ALL CH 
                             WHERE CH.CHECKRUN_ID = PARAMETERS_P.CHECKRUN_ID
                               AND CH.PAYMENT_TYPE_FLAG = 'A'  );
        END IF;
        
    EXCEPTION
    when others then 
    
    fnd_file.PUT_LINE(fnd_file.LOG,'Unexpected Error');
    fnd_file.PUT_LINE(fnd_file.LOG,'SQLERRM : '||SQLERRM);
    END;
    fnd_file.PUT_LINE(fnd_file.LOG,'+---------------------------------------------------------------------------+');
    fnd_file.PUT_LINE(fnd_file.LOG,'End Log Summary Values ');
    fnd_file.PUT_LINE(fnd_file.LOG,'+---------------------------------------------------------------------------+');
    
    fnd_file.PUT_LINE(fnd_file.LOG,'Registro de Pagos ');
    fnd_file.PUT_LINE(fnd_file.LOG,'BANK              : '||V_BANK_NAME );
    fnd_file.PUT_LINE(fnd_file.LOG,'BANK ACCOUNT NAME : '||V_BANK_ACC_NAME  );
    fnd_file.PUT_LINE(fnd_file.LOG,'PAYMENT DOCUMENT  : '||V_PAYMENT_DOC);
    IF PARAMETERS_P.CHECKRUN_ID IS NOT NULL THEN
    fnd_file.PUT_LINE(fnd_file.LOG,'CHECKRUN NAME     : '||V_BATCH_NAME);
    END IF;
    fnd_file.PUT_LINE(fnd_file.LOG,'  ');
    
    LINE:='';
    LINE := LINE ||'  ' || RPAD('DOC SEQUENCE'   ,12, ' ');
    LINE := LINE ||'  ' || RPAD('CHECK DATE'     ,15, ' ');
    LINE := LINE ||'  ' || RPAD('SUPPLIER NAME'  ,50,' ');
    LINE := LINE ||'  ' || RPAD('VENDOR SITE'    ,15, ' ');
    LINE := LINE ||'  ' || LPAD('AMOUNT'         ,15, ' ');
    LINE := LINE ||'  ' || RPAD('CHECK STATUS'   ,15, ' ');
    LINE := LINE ||'  ' || RPAD('SEND STATUS'   ,15, ' ');
    fnd_file.PUT_LINE(fnd_file.LOG,LINE);
    
    IF PARAMETERS_P.CHECKRUN_ID IS NOT NULL THEN
                    
        FOR C IN CHECKS_BATCH(PARAMETERS_P) LOOP
            LINE:='';
            LINE := LINE ||'  ' || LPAD(TO_CHAR(NVL(C.DOC_SEQUENCE_VALUE,0))     ,12,' ');
            LINE := LINE ||'  ' || RPAD(TO_CHAR(C.CHECK_DATE,'DD/MM/YYYY')         ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_NAME,' ')                     ,50,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_SITE_CODE,' ')                ,15,' ');
            LINE := LINE ||'  ' || LPAD(TO_CHAR(C.AMOUNT,'999,999,999.99')         ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.CHECK_STATUS,' ')                    ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.SEND_STATUS,' ')                    ,15,' ');
            fnd_file.PUT_LINE(fnd_file.LOG,LINE);
        END LOOP;
        
    ELSE 
        FOR C IN CHECKS_SPECIFIC(PARAMETERS_P) LOOP
            LINE:='';
            LINE := LINE ||'  ' || LPAD(TO_CHAR(NVL(C.DOC_SEQUENCE_VALUE,0))     ,12,' ');
            LINE := LINE ||'  ' || RPAD(TO_CHAR(C.CHECK_DATE,'DD/MM/YYYY')         ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_NAME,' ')                     ,50,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_SITE_CODE,' ')                ,15,' ');
            LINE := LINE ||'  ' || LPAD(TO_CHAR(C.AMOUNT,'999,999,999.99')         ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.CHECK_STATUS,' ')                    ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.SEND_STATUS,' ')                    ,15,' ');
            fnd_file.PUT_LINE(fnd_file.LOG,LINE);
        END LOOP;
        
     END IF;

    fnd_file.PUT_LINE(fnd_file.LOG,'-----------------------------------');
    fnd_file.PUT_LINE(fnd_file.LOG,'REPORT TOTAL     :'||LPAD(TO_CHAR(SUMARY_V.SUM_TRANS,'999,999,999.99'),15,' '));
    fnd_file.PUT_LINE(fnd_file.LOG,'REPORT COUNT     :'||LPAD(TO_CHAR(SUMARY_V.TRX_LINES),15,' '));

end XX_LOG_REPORT_DETAILS;
 
/*
    #####################################################
    FUNCIONES PARA OBTENER VALORES
    #####################################################

*/

  FUNCTION XX_GET_DATE_VALUE (SQLS VARCHAR2, R_VALUES IN OUT RUNTIME_VALUES) RETURN DATE IS

    DATE_VAL VARCHAR2(400);
    CURSOR_A sys_refcursor;
        
    BEGIN
          OPEN CURSOR_A FOR SQLS;
          FETCH CURSOR_A into DATE_VAL;

          IF CURSOR_A%NOTFOUND THEN
          DATE_VAL := SYSDATE;
          END IF;

        CLOSE CURSOR_A;
        IF DATE_VAL IS NULL THEN 
            R_VALUES.ERROR_CODE := 'Error Fetching Data';
            R_VALUES.ERROR_DESC := 'No records where found';
        ELSE
            R_VALUES.ERROR_CODE := 'S';
            R_VALUES.ERROR_DESC := NULL;
        END IF;
          
    RETURN(DATE_VAL);
    --+
    EXCEPTION
    WHEN OTHERS THEN
        IF CURSOR_A%ISOPEN THEN
        CLOSE CURSOR_A;
        END IF;
        R_VALUES.ERROR_CODE := 'Unexpected Exception, sysdate was return';
        R_VALUES.ERROR_DESC := 'SQLERRM : '||SQLERRM;
        RETURN(SYSDATE);
    END XX_GET_DATE_VALUE;


  FUNCTION XX_GET_NUMBER_VALUE (SQLS VARCHAR2,R_VALUES   IN OUT RUNTIME_VALUES) RETURN NUMBER IS

    NUMBER_VAL NUMBER;
    NUMBER_STR VARCHAR2(4000);
    CURSOR_A sys_refcursor;

    BEGIN


    OPEN CURSOR_A FOR SQLS;
    FETCH CURSOR_A into NUMBER_STR;
          IF CURSOR_A%NOTFOUND THEN
          NUMBER_VAL := 999999;
          END IF;
    CLOSE CURSOR_A;
    NUMBER_VAL := TO_NUMBER(REPLACE(REPLACE(NUMBER_STR,'-',''),' ',''));
    
        IF NUMBER_VAL IS NULL THEN 
            R_VALUES.ERROR_CODE := 'Error Fetching Data';
            R_VALUES.ERROR_DESC := 'No records where found';
        ELSE
            R_VALUES.ERROR_CODE := 'S';
            R_VALUES.ERROR_DESC := NULL;
        END IF;
        

    RETURN(NUMBER_VAL);

    EXCEPTION
    WHEN OTHERS THEN
          IF CURSOR_A%ISOPEN THEN
          CLOSE CURSOR_A;
          END IF;
        R_VALUES.ERROR_CODE := 'Unexpected Exception, 9999999 was return';
        R_VALUES.ERROR_DESC := 'SQLERRM : '||SQLERRM;
        RETURN (9999999);
    END XX_GET_NUMBER_VALUE;


  FUNCTION XX_GET_STRING_VALUE (SQLS VARCHAR2,R_VALUES IN OUT RUNTIME_VALUES) RETURN VARCHAR2 IS

  STR_VAR VARCHAR2(4000);
  CURSOR_A sys_refcursor;

BEGIN

    OPEN CURSOR_A FOR SQLS;
    FETCH CURSOR_A into STR_VAR;
    IF CURSOR_A%NOTFOUND THEN
    STR_VAR :=' ';
    END IF;
    CLOSE CURSOR_A;
    
    IF STR_VAR IS NULL THEN 
        R_VALUES.ERROR_CODE := 'Error Fetching Data';
        R_VALUES.ERROR_DESC := 'No records where found';
    ELSE
        R_VALUES.ERROR_CODE := 'S';
        R_VALUES.ERROR_DESC := NULL;
    END IF;
        
    RETURN(STR_VAR);

EXCEPTION
    WHEN OTHERS THEN
        IF CURSOR_A%ISOPEN THEN
        CLOSE CURSOR_A;
        END IF;
    
    R_VALUES.ERROR_CODE := 'Unexpected Exception, CURSOR-EXEPTION-STRING was return';
    R_VALUES.ERROR_DESC := 'SQLERRM : '||SQLERRM;
    RETURN 'CURSOR-EXEPTION-STRING';
END XX_GET_STRING_VALUE;
  
  
FUNCTION XX_IDENTIFY_ALTER_SQL_STRINGS (IN_SQLS IN VARCHAR2, P IN REPORT_PARAMETER) RETURN VARCHAR2 IS

INI NUMBER;
SQL_ALT VARCHAR2(4000);
SQL_DEF VARCHAR2(4000);
BEGIN
    INI := INSTR(IN_SQLS,'/*SQLS_ALT*/',1,1);
    
    IF  INI > 0 THEN 
        SQL_ALT := SUBSTR(IN_SQLS , INI + 12,LENGTH(IN_SQLS));
        SQL_DEF := SUBSTR(IN_SQLS , 1, INI-1 );
    ELSE
        SQL_ALT := IN_SQLS;
        SQL_DEF := IN_SQLS;
    END IF;
    
    IF  P.CHECKRUN_ID IS NOT NULL THEN
        RETURN (SQL_DEF);
    ELSE 
        RETURN (SQL_ALT);
    END IF;
    
END;
  
FUNCTION XX_GET_CHECK_AMOUNT(CHECKID IN NUMBER) RETURN NUMBER IS
OUT_AMOUNT NUMBER;
BEGIN
    SELECT CH.AMOUNT
      INTO OUT_AMOUNT
      FROM APPS.AP_CHECKS_ALL CH
     WHERE CH.CHECK_ID = CHECKID;
     RETURN (OUT_AMOUNT);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
    RETURN 0;
    WHEN TOO_MANY_ROWS THEN
    RETURN 0;
    WHEN OTHERS THEN
    RETURN 0;
END XX_GET_CHECK_AMOUNT;

FUNCTION XX_PADING_WITH_STR_PAD_DIR_LEN(STR VARCHAR2, PAD VARCHAR2, DIR VARCHAR2 ,LEN NUMBER) RETURN VARCHAR2 IS
OUT_STR VARCHAR2(4000);
    BEGIN

    CASE DIR
    WHEN 'RIGHT' THEN
    OUT_STR := RPAD(STR,LEN,PAD);

    WHEN 'LEFT' THEN
    OUT_STR := LPAD(STR,LEN,PAD);
    ELSE
    OUT_STR := STR;
    END CASE;

    RETURN OUT_STR;

EXCEPTION
    WHEN OTHERS THEN
    RETURN ('xxxxxxxxx');
  END XX_PADING_WITH_STR_PAD_DIR_LEN;


/* 
   #############################################################
        FUNCION XX_GENERATE_VALUE
        PROPOCITO : CREAR EL VALOR DE CADA CAMPO
   ##############################################################
*/

FUNCTION XX_GENERATE_VALUE (  SQLST      VARCHAR2   --1
                             ,TYPE_VAL   VARCHAR2   --2
                             ,CHECK_ID   NUMBER     --3
                             ,INVOICE_ID NUMBER     --4
                             ,DATA_TYPE  VARCHAR2   --5
                             ,FORMAT     VARCHAR2   --6
                             ,CONST_VAL  VARCHAR2   --7
                             ,NEEDS_PA   VARCHAR2   --10
                             ,PAD_CHAR   VARCHAR2   --11
                             ,PAD_DIR    VARCHAR2   --12
                             ,LEN        NUMBER     --13
                             ,TYPE_FILE  VARCHAR2   --14
                             ,DELIMITER  VARCHAR2   --15
                             ,PARAMETER  REPORT_PARAMETER
                             ,R_VALUES   IN OUT RUNTIME_VALUES
                            )RETURN     VARCHAR2 IS

    OUT_STR    VARCHAR2(4000);
    DATE_VAL   DATE;
    NUMBER_VAL NUMBER;
    SQL_STATEMENT VARCHAR2(4000);
    PAD_CHARACTER VARCHAR2(1);
    DELIMIT_CHAR VARCHAR2(1);
    CONSTANT_VALUE VARCHAR2(4000);
begin


        CASE TYPE_VAL

        WHEN 'DINAMIC' THEN
            SQL_STATEMENT := XX_IDENTIFY_ALTER_SQL_STRINGS(SQLST,PARAMETER);
            
            IF  CHECK_ID IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':IDCHECK',CHECK_ID);
            END IF;
                
            IF  INVOICE_ID  IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':INVOICEID',INVOICE_ID);
            END IF;
            
            IF  PARAMETER.CHECKRUN_ID IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':IDCHECKRUN',PARAMETER.CHECKRUN_ID);
            ELSE 
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':IDCHECKRUN','CH.CHECKRUN_ID');
            END IF;
               
            IF  PARAMETER.PAY_DOCUMENT  IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':PAY_DOCUMENT',PARAMETER.PAY_DOCUMENT);
            ELSE
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':PAY_DOCUMENT','CH.PAYMENT_DOCUMENT_ID');
            END IF;

            IF  PARAMETER.P_START_DATE  IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':P_START_DATE',''''||PARAMETER.P_START_DATE||'''' );
            ELSE
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':P_START_DATE','TO_CHAR(CH.CHECK_DATE,''YYYY/MM/DD HH24:MI:SS'')');
            END IF;
              
            IF  PARAMETER.P_END_DATE    IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':P_END_DATE' ,''''||PARAMETER.P_END_DATE||'''');
            ELSE
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':P_END_DATE' ,'TO_CHAR(CH.CHECK_DATE,''YYYY/MM/DD HH24:MI:SS'')');
            END IF;
                
            IF  PARAMETER.BASE_AMOUNT   IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':BASE_AMOUNT',PARAMETER.BASE_AMOUNT);
            ELSE
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':BASE_AMOUNT',PARAMETER.TOP_AMOUNT);
            END IF;
                
            IF  PARAMETER.TOP_AMOUNT    IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':TOP_AMOUNT',PARAMETER.TOP_AMOUNT);
            ELSE 
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':TOP_AMOUNT',PARAMETER.TOP_AMOUNT);
            END IF;
                
            IF  PARAMETER.P_DOC_INI     IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':P_DOC_INI',PARAMETER.P_DOC_INI);
            ELSE 
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':P_DOC_INI','CH.DOC_SEQUENCE_VALUE');
            END IF;
                
            IF  PARAMETER.P_DOC_FIN     IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':P_DOC_FIN',PARAMETER.P_DOC_FIN);
            ELSE
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':P_DOC_FIN','CH.DOC_SEQUENCE_VALUE');
            END IF;
           
            IF  PARAMETER.ALL_CHECKS  IS NOT NULL THEN
                SQL_STATEMENT := REPLACE(SQL_STATEMENT,':ALL_CHECKS',''''||PARAMETER.ALL_CHECKS||'''');
            END IF;
            /*
            IF  PARAMETER.CHECKRUN_ID IS NOT NULL THEN
            fnd_file.PUT_LINE(fnd_file.OUTPUT,'SQL_STATEMENT ->'||SQL_STATEMENT);
            END IF;
            */
            R_VALUES.ERROR_CODE := NULL;
            R_VALUES.ERROR_DESC := NULL;
            CASE DATA_TYPE
            WHEN 'DATE' THEN
            DATE_VAL := XX_GET_DATE_VALUE(SQL_STATEMENT,R_VALUES);

            WHEN 'NUMBER' THEN
            NUMBER_VAL := XX_GET_NUMBER_VALUE(SQL_STATEMENT,R_VALUES);

            WHEN 'STRING' THEN
            OUT_STR := XX_GET_STRING_VALUE(SQL_STATEMENT,R_VALUES);
            ELSE
            OUT_STR := XX_GET_STRING_VALUE(SQL_STATEMENT,R_VALUES);
            END CASE;
            
            IF R_VALUES.ERROR_CODE != 'S' THEN
                fnd_file.PUT_LINE(fnd_file.LOG,'Error Code    : '||R_VALUES.ERROR_CODE);
                fnd_file.PUT_LINE(fnd_file.LOG,'Description   : '||R_VALUES.ERROR_DESC);
                fnd_file.PUT_LINE(fnd_file.LOG,'CHECK_ID      : '||CHECK_ID);
                fnd_file.PUT_LINE(fnd_file.LOG,'SQL Statement : '||SQL_STATEMENT);
            END IF;
            
        WHEN 'CONSTANT' THEN
        
            CONSTANT_VALUE := CONST_VAL;
            CONSTANT_VALUE := REPLACE (CONSTANT_VALUE,'\T',CHR(9));
            CONSTANT_VALUE := REPLACE (CONSTANT_VALUE,'\E',' ');
            CONSTANT_VALUE := REPLACE (CONSTANT_VALUE,'\N','');
            OUT_STR := CONSTANT_VALUE;

        WHEN 'SEQUENCE1' THEN NUMBER_VAL := R_VALUES.SEQUENCE1;
        WHEN 'SEQUENCE2' THEN NUMBER_VAL := R_VALUES.SEQUENCE2;
        WHEN 'SEQUENCE3' THEN NUMBER_VAL := R_VALUES.SEQUENCE3;
        WHEN 'TRX_LINES' THEN NUMBER_VAL := R_VALUES.TRX_LINES;
        WHEN 'SUM_TRANS' THEN NUMBER_VAL := R_VALUES.SUM_TRANS;

        ELSE NULL;
        END CASE;
        
        
        CASE DATA_TYPE
        WHEN 'DATE' THEN
        OUT_STR := TO_CHAR(DATE_VAL,FORMAT);
        WHEN 'NUMBER' THEN
        OUT_STR := TRIM(TO_CHAR(NUMBER_VAL,FORMAT));
        ELSE
        NULL;
        END CASE;
    
        CASE DELIMITER
        WHEN 'T' THEN DELIMIT_CHAR := CHR(9);
        ELSE  DELIMIT_CHAR := DELIMITER;
        END CASE;

        IF NEEDS_PA = 'Y' OR TYPE_FILE = 'POSITIONS' THEN

            --fnd_file.PUT_LINE(fnd_file.OUTPUT,'PAD_CHARACTER ->'||PAD_CHARACTER);
            IF PAD_CHAR IS NULL THEN
                CASE DATA_TYPE
                WHEN 'NUMBER' THEN PAD_CHARACTER := '0';
                WHEN 'STRING' THEN PAD_CHARACTER := ' ';
                ELSE PAD_CHARACTER := ' ';
                END CASE;
            ELSE
                CASE PAD_CHAR
                WHEN 'T' THEN PAD_CHARACTER := CHR(9);
                WHEN 'E' THEN PAD_CHARACTER := ' ';
                ELSE PAD_CHARACTER := PAD_CHAR;
                END CASE;
            END IF;

            IF OUT_STR IS NULL THEN
               OUT_STR := PAD_CHARACTER;
            END IF;

            --fnd_file.PUT_LINE(fnd_file.OUTPUT,'OUT_STR ->'||OUT_STR);
            CASE PAD_DIR
            WHEN 'RIGHT' THEN OUT_STR := RPAD(OUT_STR,LEN,PAD_CHARACTER);
            WHEN 'LEFT'  THEN OUT_STR := LPAD(OUT_STR,LEN,PAD_CHARACTER);
            ELSE OUT_STR := RPAD(OUT_STR,LEN,PAD_CHARACTER);
            END CASE;

        END IF;

        --fnd_file.PUT_LINE(fnd_file.OUTPUT,'OUT_STR2 ->'||OUT_STR);
        IF  TYPE_FILE = 'DELIMITED' THEN
            CASE DELIMITER
            WHEN 'T' THEN DELIMIT_CHAR := CHR(9);
            WHEN 'E' THEN DELIMIT_CHAR := ' ';
            ELSE  DELIMIT_CHAR := DELIMITER;
            END CASE;
        OUT_STR := REPLACE(OUT_STR,DELIMIT_CHAR,'');
        OUT_STR := OUT_STR || DELIMIT_CHAR;
        END IF;

        RETURN (OUT_STR);

    EXCEPTION
        WHEN OTHERS THEN
    RETURN ('XX_EXCEPTION_STRING_XX');
END XX_GENERATE_VALUE;

PROCEDURE XX_PRINT_LOG_ERRORS (R in out RUNTIME_VALUES) IS
BEGIN 
    IF R.ERROR_CODE != 'S' THEN
        fnd_file.PUT_LINE(fnd_file.LOG,R.ERROR_CODE||' : '||R.ERROR_DESC );
    END IF;
    R.ERROR_CODE := null;
    R.ERROR_DESC := null;
    
END XX_PRINT_LOG_ERRORS;

PROCEDURE XX_VERIFY_PROCESS(P REPORT_PARAMETER, R in out RUNTIME_VALUES) IS

BEGIN

    R.ERROR_CODE := 'S';
    
    XX_GET_TRXAMOUNT_AND_TRXLINES(P,R);
    
    IF P.CHECKRUN_ID IS NULL THEN
        IF     P.P_START_DATE   IS NULL
            OR P.P_END_DATE     IS NULL
            OR P.PAY_DOCUMENT   IS NULL THEN 
            fnd_file.PUT_LINE(fnd_file.LOG,'Unexpected : Not enough parameters to continue');
            R.ERROR_CODE := 'U';
        end if;
    end if;
    
    if p.format_used is null then
        R.ERROR_CODE := 'U';
        fnd_file.PUT_LINE(fnd_file.LOG,'Unexpected : This payment Document Does not have a format asosiated with.');
    end if;
    
    IF R.TRX_LINES = 0 THEN
        fnd_file.PUT_LINE(fnd_file.LOG,'Warning : Parameters did not retrieve any data');
        R.ERROR_CODE := 'U';
    END IF;
    

END XX_VERIFY_PROCESS;

/* 
   #############################################################
        PROCEDIMIENTO  CHECKS_LINE    
        PROPOCITO : UNNA LINEA DE LA TRANSACCION Y/O EL DETALLE DE ESTA
   ##############################################################
*/

PROCEDURE CHECKS_LINE( PARAMETER REPORT_PARAMETER
                      ,FORMAT    REPORT_FORMAT
                      ,CHECK_ID  NUMBER
                      ,R_VALUES IN OUT RUNTIME_VALUES) IS

CURSOR TRX(R REPORT_PARAMETER) IS
SELECT  DT.ID_FILE_FORMAT
       ,MS.TYPE_TEXT_FILE
       ,MS.DELIMITER
       ,DT.TYPE_VALUE
       ,DT.CONSTANT_VALUE
       ,DT.SECUENCE
       ,DT.START_POSITION
       ,DT.END_POSITION
       ,DT.DATA_TYPE
       ,DT.FORMAT
       ,DT.MAX_VALUE_LENGHT
       ,DT.PADDING_CHARACTER
       ,DT.DIRECTION_PADDING
       ,DT.NEEDS_PADDING
       ,DT.SQL_STATEMENT
  FROM  XX_SV_AP_EPAYMENT_DETAIL DT
       ,XX_SV_AP_EPAYMENT_MASTER MS
 WHERE 1=1
   and ms.ID_MASTER = R.FORMAT_USED
   AND DT.ID_MASTER = MS.ID_MASTER
   AND MS.ENABLE = 'Y'
   AND DT.PART_OF_FILE = 'TRX'
 ORDER BY DT.SECUENCE ASC;


CURSOR  DETAIL (R REPORT_PARAMETER) IS
SELECT  DT.ID_FILE_FORMAT
       ,MS.TYPE_TEXT_FILE
       ,MS.DELIMITER
       ,DT.TYPE_VALUE
       ,DT.CONSTANT_VALUE
       ,DT.SECUENCE
       ,DT.START_POSITION
       ,DT.END_POSITION
       ,DT.DATA_TYPE
       ,DT.FORMAT
       ,DT.MAX_VALUE_LENGHT
       ,DT.PADDING_CHARACTER
       ,DT.DIRECTION_PADDING
       ,DT.NEEDS_PADDING
       ,DT.SQL_STATEMENT
  FROM  XX_SV_AP_EPAYMENT_DETAIL DT
       ,XX_SV_AP_EPAYMENT_MASTER MS
 WHERE 1=1
   and ms.ID_MASTER = R.FORMAT_USED
   AND DT.ID_MASTER = MS.ID_MASTER
   AND DT.PART_OF_FILE = 'DETAIL'
   AND MS.ENABLE = 'Y'
 ORDER BY DT.SECUENCE ASC;


CURSOR INVOICES(CHKID NUMBER) IS
SELECT  IA.INVOICE_ID
  FROM  APPS.AP_INVOICES_ALL  IA
       ,APPS.AP_INVOICE_PAYMENTS_ALL  IPA
       ,AP_CHECKS_ALL     CH
 WHERE CH.CHECK_ID = IPA.CHECK_ID
   AND IPA.INVOICE_ID = IA.INVOICE_ID
   AND CH.CHECK_ID = CHKID;


TRX_LINE    VARCHAR2(4000);
DETAIL_LINE VARCHAR2(4000);
FIELD       VARCHAR2(4000);

BEGIN
    
    TRX_LINE :='';
    
    FOR Q IN TRX(PARAMETER) LOOP

    FIELD:= XX_GENERATE_VALUE (
          Q.SQL_STATEMENT        --1
         ,Q.TYPE_VALUE           --2
         ,CHECK_ID               --3
         ,NULL                   --4
         ,Q.DATA_TYPE            --5
         ,Q.FORMAT               --6
         ,Q.CONSTANT_VALUE       --7
         ,Q.NEEDS_PADDING        --8
         ,Q.PADDING_CHARACTER    --9
         ,Q.DIRECTION_PADDING    --10
         ,Q.END_POSITION - Q.START_POSITION + 1   --11
         ,Q.TYPE_TEXT_FILE       --12
         ,Q.DELIMITER            --13
         ,NULL                   --14
         ,R_VALUES               --15
          );

    TRX_LINE := TRX_LINE||FIELD;
    --fnd_file.PUT_LINE(fnd_file.OUTPUT,'PART '||PART);
    END LOOP;

    IF FORMAT.TYPE_TEXT_FILE = 'DELIMITED' THEN
    TRX_LINE := SUBSTR(TRX_LINE,1,LENGTH(TRX_LINE)-1);
    END IF;

    fnd_file.PUT_LINE(fnd_file.OUTPUT,TRX_LINE);

    IF FORMAT.TRX_DETAIL = 1 THEN

        R_VALUES.SEQUENCE2:= 1;

        FOR W IN INVOICES(CHECK_ID) LOOP

            DETAIL_LINE := '';

            FOR H IN DETAIL(PARAMETER) LOOP

            FIELD := XX_GENERATE_VALUE (
                     H.SQL_STATEMENT, --1
                     H.TYPE_VALUE ,     --2
                     CHECK_ID   ,       --3
                     W.INVOICE_ID,      --4
                     H.DATA_TYPE,       --5
                     H.FORMAT,          --6
                     H.CONSTANT_VALUE, --9
                     H.NEEDS_PADDING,   --10
                     H.PADDING_CHARACTER,--11
                     H.DIRECTION_PADDING,       --12
                     H.END_POSITION - H.START_POSITION +1,        --13
                     H.TYPE_TEXT_FILE,      --14
                     H.DELIMITER,           --15
                     NULL,
                     R_VALUES
            );

            --fnd_file.PUT_LINE(fnd_file.OUTPUT,'PART2 '||PART2);
            DETAIL_LINE := DETAIL_LINE||FIELD;

            END LOOP;


            IF FORMAT.TYPE_TEXT_FILE = 'DELIMITED' THEN
            DETAIL_LINE := SUBSTR(DETAIL_LINE,1,LENGTH(DETAIL_LINE)-1);
            END IF;

            fnd_file.PUT_LINE(fnd_file.OUTPUT,DETAIL_LINE);

            R_VALUES.SEQUENCE2 := R_VALUES.SEQUENCE2 + 1;
            R_VALUES.SEQUENCE3 := R_VALUES.SEQUENCE3 + 1;

        END LOOP;
    
    END IF;

    R_VALUES.SEQUENCE1 := R_VALUES.SEQUENCE1 + 1;
    R_VALUES.SEQUENCE3 := R_VALUES.SEQUENCE3 + 1;
                      
END CHECKS_LINE;                       
                      

function xx_sv_get_format(pay_document in number) return number is
id_format number;
begin 
    select ms.ID_MASTER
      into id_format
      from XX_SV_AP_EPAYMENT_MASTER ms
          ,apps.ce_payment_documents dc
     where dc.PAYMENT_DOCUMENT_ID = pay_document
       AND ms.ID_MASTER = to_number(dc.ATTRIBUTE11);
       return (id_format);
exception 
    when no_data_found then
    return(null);
    when too_many_rows then
    return(null);
end xx_sv_get_format;
/* 
   #############################################################
        PROCEDIMIENTO PRINCIPAL 
        PROPOCITO : CREAR LA ESTUCTURA DEL ARCHIVO
   ##############################################################
*/

procedure XX_FLEX_BANK_FILE (
          ERRBUF     OUT  VARCHAR2,
          RETCODE    OUT  VARCHAR2,
          BANK_ID           NUMBER,
          BANK_ACC          NUMBER,
          PAY_DOCUMENT      NUMBER,
          P_START_DATE    VARCHAR2,
          P_END_DATE      VARCHAR2,
          CHECKRUN_ID       NUMBER,
          P_DOC_INI         NUMBER,
          P_DOC_FIN         NUMBER,
          BASE_AMOUNT       NUMBER,
          TOP_AMOUNT        NUMBER
) IS
    
    PARAMETERS_P REPORT_PARAMETER;  --RECORD DE LOS PARAMETROS DEL CONCURRENTE
    FORMAT_C     REPORT_FORMAT;
    R_VALUES     RUNTIME_VALUES;
    FIELD       VARCHAR2(4000);
    LINE        VARCHAR2(4000);
    
    CURSOR FORMAT(p report_parameter) IS
        SELECT DISTINCT
           MS.ID_MASTER
          ,MS.DELIMITER
          ,MS.MAX_VALUE_LENGTH
          ,MS.TYPE_TEXT_FILE
          ,DT.PART_OF_FILE
      FROM XX_SV_AP_EPAYMENT_MASTER MS
          ,XX_SV_AP_EPAYMENT_DETAIL DT
     WHERE 1=1
       and ms.ID_MASTER = p.FORMAT_USED
       AND MS.ENABLE = 'Y'
       AND MS.ID_MASTER = DT.ID_MASTER;


CURSOR CHECKS_SPECIFIC(P REPORT_PARAMETER) IS
SELECT CH.CHECK_ID
  FROM AP_CHECKS_ALL CH
 WHERE 1=1
   AND CH.PAYMENT_DOCUMENT_ID = P.PAY_DOCUMENT
   AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(P.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
   AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(P.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
   AND CH.DOC_SEQUENCE_VALUE >= NVL(P.P_DOC_INI,CH.DOC_SEQUENCE_VALUE)
   AND CH.DOC_SEQUENCE_VALUE <= NVL(P.P_DOC_FIN,CH.DOC_SEQUENCE_VALUE)
   AND CH.AMOUNT >= NVL(P.BASE_AMOUNT ,CH.AMOUNT)
   AND CH.AMOUNT <= NVL(P.TOP_AMOUNT  ,CH.AMOUNT)
   AND PAYMENT_METHOD_CODE = 'EFT'
   AND NVL(CH.ATTRIBUTE14,'NEW') = 'NEW'
   AND CH.VOID_DATE IS NULL;
   

CURSOR CHECKS_BATCH(P REPORT_PARAMETER) IS
SELECT CH.CHECK_ID
  FROM AP_CHECKS_ALL CH
 WHERE 1=1
   AND CH.PAYMENT_DOCUMENT_ID = P.PAY_DOCUMENT
   AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(P.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
   AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(P.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
   AND CH.AMOUNT >= NVL(P.BASE_AMOUNT ,CH.AMOUNT)
   AND CH.AMOUNT <= NVL(P.TOP_AMOUNT  ,CH.AMOUNT)
   AND CH.CHECKRUN_ID = P.CHECKRUN_ID
   AND PAYMENT_METHOD_CODE = 'EFT'
   AND NVL(CH.ATTRIBUTE14,'NEW') = 'NEW'
   AND CH.VOID_DATE IS NULL;


CURSOR SUMARY(PART VARCHAR2,p report_parameter) IS
    SELECT  DT.ID_FILE_FORMAT
           ,MS.TYPE_TEXT_FILE
           ,MS.DELIMITER
           ,DT.TYPE_VALUE
           ,DT.CONSTANT_VALUE
           ,DT.SECUENCE
           ,DT.DATA_TYPE
           ,DT.FORMAT
           ,DT.MAX_VALUE_LENGHT
           ,DT.END_POSITION
           ,DT.START_POSITION
           ,DT.PADDING_CHARACTER
           ,DT.DIRECTION_PADDING
           ,DT.NEEDS_PADDING
           ,DT.SQL_STATEMENT
      FROM  XX_SV_AP_EPAYMENT_DETAIL DT
           ,XX_SV_AP_EPAYMENT_MASTER MS
     WHERE 1=1
       and ms.ID_MASTER = p.FORMAT_USED
       AND DT.ID_MASTER = MS.ID_MASTER
       AND DT.PART_OF_FILE = PART
       AND MS.ENABLE = 'Y'
     ORDER BY DT.SECUENCE ASC;



    BEGIN
        --fnd_file.PUT_LINE(fnd_file.OUTPUT,'Base Amount'||BASE_AMOUNT);
        --fnd_file.PUT_LINE(fnd_file.OUTPUT,'Top Amount'||TOP_AMOUNT);
       
        R_VALUES.SEQUENCE1  := 0;
        R_VALUES.SEQUENCE2  := 0;
        R_VALUES.SUM_TRANS  := 0;
        R_VALUES.TRX_LINES  := 0;
    
    
        PARAMETERS_P.FORMAT_USED  := XX_SV_GET_FORMAT(PAY_DOCUMENT);
        
        PARAMETERS_P.BANK_ID      := BANK_ID;
        PARAMETERS_P.BANK_ACC     := BANK_ACC; 
        PARAMETERS_P.PAY_DOCUMENT := PAY_DOCUMENT; 
        PARAMETERS_P.P_START_DATE := P_START_DATE; 
        PARAMETERS_P.P_END_DATE   := P_END_DATE;
        PARAMETERS_P.BASE_AMOUNT  := BASE_AMOUNT; 
        PARAMETERS_P.TOP_AMOUNT   := TOP_AMOUNT;
        PARAMETERS_P.P_DOC_INI    := P_DOC_INI;
        PARAMETERS_P.P_DOC_FIN    := P_DOC_FIN;
        PARAMETERS_P.CHECKRUN_ID  := CHECKRUN_ID;
        
        
        fnd_file.PUT_LINE(fnd_file.LOG,'Start process log');
        fnd_file.PUT_LINE(fnd_file.LOG,'+---------------------------------------------------------------------------+');
        
        XX_VERIFY_PROCESS(PARAMETERS_P,R_VALUES);
        
        fnd_file.PUT_LINE(fnd_file.LOG,'Error Code: '||R_VALUES.ERROR_CODE);
        
        IF  R_VALUES.ERROR_CODE != 'S' THEN
            R_VALUES.START_FLAG := 'N';
            
            IF R_VALUES.ERROR_CODE = 'E' THEN
            RETCODE := 1;
            ELSIF R_VALUES.ERROR_CODE = 'U' THEN
            RETCODE := 2;
            END IF;
            
        ELSE
        
            R_VALUES.START_FLAG := 'Y';
                    
            XX_GET_SUMARY_VALUES  (PARAMETERS_P, R_VALUES);
            
            FOR R IN FORMAT(PARAMETERS_P) LOOP
            
            FORMAT_C.TYPE_TEXT_FILE   := R.TYPE_TEXT_FILE;
            FORMAT_C.DELIMITER        := R.DELIMITER;

                CASE R.PART_OF_FILE
                WHEN 'HEADER' THEN  FORMAT_C.TRX_HEADER := 1;
                WHEN 'TRX'    THEN  FORMAT_C.TRX_BODY   := 1;
                WHEN 'DETAIL' THEN  FORMAT_C.TRX_DETAIL := 1;
                WHEN 'FOOTER' THEN  FORMAT_C.TRX_FOOTER := 1;
                ELSE NULL;
                END CASE;

            END LOOP;


            IF FORMAT_C.TRX_HEADER = 1 THEN

                FOR L IN SUMARY('HEADER',PARAMETERS_P) LOOP

                    FIELD := XX_GENERATE_VALUE (
                             L.SQL_STATEMENT,
                             L.TYPE_VALUE ,
                             NULL,
                             NULL,
                             L.DATA_TYPE,
                             L.FORMAT,
                             L.CONSTANT_VALUE,
                             L.NEEDS_PADDING,
                             L.PADDING_CHARACTER,
                             L.DIRECTION_PADDING,
                             L.END_POSITION - L.START_POSITION + 1,
                             L.TYPE_TEXT_FILE,
                             L.DELIMITER,
                             PARAMETERS_P,
                             R_VALUES
                            );

                         LINE := LINE||FIELD;
                END LOOP;

                IF FORMAT_C.TYPE_TEXT_FILE = 'DELIMITED' THEN
                LINE := SUBSTR(LINE,1,LENGTH(LINE)-1);
                END IF;

                fnd_file.PUT_LINE(fnd_file.OUTPUT,LINE);

            END IF;
            

            IF FORMAT_C.TRX_BODY = 1 THEN
                
                R_VALUES.SEQUENCE1:= 1;
                
                IF CHECKRUN_ID IS NOT NULL THEN
                
                   -- fnd_file.PUT_LINE(fnd_file.LOG,'Archive created using Check Batch');
                    
                    FOR Y IN CHECKS_BATCH(PARAMETERS_P) LOOP
                    
                        CHECKS_LINE( PARAMETER => PARAMETERS_P
                                    ,FORMAT    => FORMAT_C
                                    ,CHECK_ID  => Y.CHECK_ID
                                    ,R_VALUES  => R_VALUES);
                    END LOOP;
                    
                ELSE 
                
                   -- fnd_file.PUT_LINE(fnd_file.LOG,'Archive created using Pay Documents');    
                
                    FOR Y IN CHECKS_SPECIFIC(PARAMETERS_P) LOOP
                    
                        CHECKS_LINE( PARAMETER => PARAMETERS_P
                                    ,FORMAT    => FORMAT_C
                                    ,CHECK_ID  => Y.CHECK_ID
                                    ,R_VALUES  => R_VALUES);
                    END LOOP;
                  
                    /*
                    RETCODE := 1;
                    fnd_file.PUT_LINE(fnd_file.OUTPUT,'Wrong Parameters :');   
                    fnd_file.PUT_LINE(fnd_file.OUTPUT,'Payments by batch have higer priority');
                    fnd_file.PUT_LINE(fnd_file.OUTPUT,'Try with all parameters but batch');      
                    */     
                
                END IF;
            
            END IF;


            IF FORMAT_C.TRX_FOOTER = 1 THEN

                FOR L IN SUMARY('FOOTER',PARAMETERS_P) LOOP

                    FIELD := XX_GENERATE_VALUE (
                         L.SQL_STATEMENT,
                         L.TYPE_VALUE ,
                         NULL,
                         NULL,
                         L.DATA_TYPE,
                         L.FORMAT,
                         L.CONSTANT_VALUE,
                         L.NEEDS_PADDING,
                         L.PADDING_CHARACTER,
                         L.DIRECTION_PADDING,
                         L.END_POSITION - L.START_POSITION +1,
                         L.TYPE_TEXT_FILE,
                         L.DELIMITER,
                         PARAMETERS_P,
                         R_VALUES
                            );

                         LINE := LINE||FIELD;
                END LOOP;

                IF FORMAT_C.TYPE_TEXT_FILE = 'DELIMITED' THEN
                LINE := SUBSTR(LINE,1,LENGTH(LINE)-1);
                END IF;

                fnd_file.PUT_LINE(fnd_file.OUTPUT,LINE);

            END IF;
            
        END IF;
       
        fnd_file.PUT_LINE(fnd_file.LOG,'+---------------------------------------------------------------------------+');
        fnd_file.PUT_LINE(fnd_file.LOG,'End process log');
        
        IF R_VALUES.START_FLAG = 'Y' THEN
          XX_LOG_REPORT_DETAILS (PARAMETERS_P);
          XX_UPDATE_PROCESS_CHECKS(PARAMETERS_P);
        end if;
        
    retcode := '0';

    EXCEPTION
         WHEN OTHERS
         THEN
      retcode := '2';
      errbuf := SQLERRM;
     ROLLBACK;

    END XX_FLEX_BANK_FILE;


PROCEDURE XX_UPDATE_CHECKS_STATUS (
          ERRBUF     OUT  VARCHAR2,
          RETCODE    OUT  VARCHAR2,
          BANK_ID           NUMBER,
          BANK_ACC          NUMBER,
          PAY_DOCUMENT      NUMBER,
          P_START_DATE    VARCHAR2,
          P_END_DATE      VARCHAR2,
          CHECKRUN_ID       NUMBER,
          P_DOC_INI         NUMBER,
          P_DOC_FIN         NUMBER,
          BASE_AMOUNT       NUMBER,
          TOP_AMOUNT        NUMBER,
          SET_STATUS      VARCHAR2,
          LOGGED_USER       NUMBER ) IS

    ROWS_UPDATED NUMBER;   
    USER_GRANTED_ID  NUMBER;    
    PARAMETERS_P report_parameter;   
BEGIN
        PARAMETERS_P.BANK_ID      := BANK_ID;
        PARAMETERS_P.BANK_ACC     := BANK_ACC; 
        PARAMETERS_P.PAY_DOCUMENT := PAY_DOCUMENT; 
        PARAMETERS_P.P_START_DATE := P_START_DATE; 
        PARAMETERS_P.P_END_DATE   := P_END_DATE;
        PARAMETERS_P.BASE_AMOUNT  := BASE_AMOUNT; 
        PARAMETERS_P.TOP_AMOUNT   := TOP_AMOUNT;
        PARAMETERS_P.P_DOC_INI    := P_DOC_INI;
        PARAMETERS_P.P_DOC_FIN    := P_DOC_FIN;
        PARAMETERS_P.CHECKRUN_ID  := CHECKRUN_ID;
        
    BEGIN
        SELECT usr.USER_ID
        INTO USER_GRANTED_ID
        FROM APPS.FND_FLEX_VALUE_SETS FVS1,
             APPS.FND_FLEX_VALUES FV1,
             APPS.FND_FLEX_VALUES_TL FVT1,
             apps.fnd_user   usr
        WHERE FVS1.FLEX_VALUE_SET_NAME = 'XXSVAPSETUPSTATUSCHECK'
        AND FVS1.FLEX_VALUE_SET_ID = FV1.FLEX_VALUE_SET_ID
        AND FV1.FLEX_VALUE_ID = FVT1.FLEX_VALUE_ID
        AND FVT1.LANGUAGE = 'US'
        AND FV1.ENABLED_FLAG = 'Y'
        AND trunc(SYSDATE) BETWEEN trunc(NVL(FV1.START_DATE_ACTIVE,SYSDATE)) AND trunc(NVL(FV1.END_DATE_ACTIVE,SYSDATE))
        and usr.USER_ID = LOGGED_USER
        AND upper(trim(FVT1.FLEX_VALUE_MEANING)) = usr.USER_NAME;
        
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN 
    ERRBUF  := 'User Does not have Access';
    RETCODE := 1;
    when too_many_rows then
    ERRBUF  := 'Contac Payables Setup Administator for Help';
    RETCODE := 1;
    when others then
    ERRBUF  := sqlerrm;
    RETCODE := 2;
    END;
    
    IF USER_GRANTED_ID IS NOT NULL THEN
    
        IF CHECKRUN_ID IS NOT NULL THEN
        UPDATE AP_CHECKS_ALL CH
           SET CH.ATTRIBUTE14 = SET_STATUS
         WHERE 1=1
           AND CH.PAYMENT_DOCUMENT_ID = PARAMETERS_P.PAY_DOCUMENT
           AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(PARAMETERS_P.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
           AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(PARAMETERS_P.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
           AND CH.AMOUNT >= NVL(PARAMETERS_P.BASE_AMOUNT ,CH.AMOUNT)
           AND CH.AMOUNT <= NVL(PARAMETERS_P.TOP_AMOUNT  ,CH.AMOUNT)
           AND CH.CHECKRUN_ID = PARAMETERS_P.CHECKRUN_ID
           AND PAYMENT_METHOD_CODE = 'EFT'
           AND CH.VOID_DATE IS NULL;
       
        ELSE
            
        UPDATE AP_CHECKS_ALL CH
           SET CH.ATTRIBUTE14 = SET_STATUS
         WHERE 1=1
           AND CH.PAYMENT_DOCUMENT_ID = PARAMETERS_P.PAY_DOCUMENT
           AND TRUNC(CH.CHECK_DATE) >= TRUNC(TO_DATE(PARAMETERS_P.P_START_DATE,'YYYY/MM/DD HH24:MI:SS'))
           AND TRUNC(CH.CHECK_DATE) <= TRUNC(TO_DATE(PARAMETERS_P.P_END_DATE  ,'YYYY/MM/DD HH24:MI:SS'))
           AND CH.DOC_SEQUENCE_VALUE >= NVL(PARAMETERS_P.P_DOC_INI,CH.DOC_SEQUENCE_VALUE)
           AND CH.DOC_SEQUENCE_VALUE <= NVL(PARAMETERS_P.P_DOC_FIN,CH.DOC_SEQUENCE_VALUE)
           AND CH.AMOUNT >= NVL(PARAMETERS_P.BASE_AMOUNT ,CH.AMOUNT)
           AND CH.AMOUNT <= NVL(PARAMETERS_P.TOP_AMOUNT  ,CH.AMOUNT)
           AND PAYMENT_METHOD_CODE = 'EFT'
           AND CH.VOID_DATE IS NULL;
        END IF;
        
        ROWS_UPDATED := SQL%Rowcount;
        fnd_file.Put_Line(fnd_file.output,'Checks Updated : '||to_char(ROWS_UPDATED,'99999999'));
        RETCODE  := '0';
        COMMIT;
        XX_LOG_REPORT_DETAILS(PARAMETERS_P);
        
    ELSE
    fnd_file.Put_Line(fnd_file.output,'User Does not have Access');
    end if;

END XX_UPDATE_CHECKS_STATUS;



END XX_SV_EPAYMENT;
/
create or replace public synonym XX_SV_EPAYMENT for BOLINF.XX_SV_EPAYMENT;
/
GRANT ALL ON BOLINF.XX_SV_EPAYMENT TO APPS WITH GRANT OPTION;
/
exit
/