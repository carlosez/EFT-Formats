CREATE OR REPLACE PACKAGE BOLINF.XX_SV_EPAYMENT AS

FUNCTION XX_GET_INVOICE_NUM (P_INVOICE_ID NUMBER) RETURN VARCHAR2;

FUNCTION XX_GET_INVOICES (P_CHECK_ID NUMBER) RETURN VARCHAR2;

PROCEDURE XX_CREATE_BANK_FILE (
      errbuf        OUT   VARCHAR2,
      retcode       OUT   VARCHAR2,
      BANK_USED             NUMBER,
      P_START_DATE        VARCHAR2,
      P_END_DATE          VARCHAR2
);


TYPE REPORT_PARAMETER IS RECORD(
                                BANK_ID           NUMBER,
                                BANK_ACC          NUMBER,
                                PAY_DOCUMENT      NUMBER,
                                FORMAT_USED       NUMBER,
                                P_START_DATE      VARCHAR2(23),
                                P_END_DATE        VARCHAR2(23),
                                BASE_AMOUNT       NUMBER,
                                TOP_AMOUNT        NUMBER,
                                P_DOC_INI         NUMBER,
                                P_DOC_FIN         NUMBER,       -- IN CASE OF A RANGE OF PAYMENTS
                                CHECKRUN_ID       NUMBER,       -- FOR PAYMENT BATCH
                                ALL_CHECKS        VARCHAR2(100), --WHETHER IS NEW OR ALL CHECKS
                                STATUS_CHECK      VARCHAR(150)
                                );

TYPE REPORT_FORMAT IS RECORD(
                                TRX_HEADER       NUMBER,
                                TRX_BODY         NUMBER,
                                TRX_DETAIL       NUMBER,
                                TRX_FOOTER       NUMBER,
                                TYPE_TEXT_FILE   XX_SV_AP_EPAYMENT_MASTER.TYPE_TEXT_FILE%type,
                                DELIMITER        XX_SV_AP_EPAYMENT_MASTER.DELIMITER%type
                                );
TYPE RUNTIME_VALUES IS RECORD(
                          SEQUENCE1    NUMBER  --CURRENT NUMBER RECORD IN TRX
                         ,SEQUENCE2    NUMBER  --CURRENT NUMBER RECORD IN DETAIL
                         ,SEQUENCE3    NUMBER  --CURRENT LINE IN ARCHIVE TRX AND DETAIL
                         ,DETAIL_LINES NUMBER  --SUM OF ALL DETAIL LINES IN A TRX
                         ,TRX_LINES    NUMBER  --+ COUNT OF ALL TRX IN ARCHIVE
                         ,SUM_TRANS    NUMBER  --+ SUM OF TRX AMOUNTS
                         ,REPORT_LINES NUMBER  --+ COUNT OF ALL LINES IN REPORT TRX+DETAIL
                         ,ERROR_DESC VARCHAR2(4000)
                         ,ERROR_CODE VARCHAR2(4000)
                         ,SQLERRMSG  VARCHAR2(4000)
                         ,START_FLAG VARCHAR2(1)
                         );


FUNCTION XX_GET_DATE_VALUE (SQLS VARCHAR2,R_VALUES IN OUT RUNTIME_VALUES) RETURN DATE;

FUNCTION XX_GET_NUMBER_VALUE (SQLS VARCHAR2,R_VALUES IN OUT RUNTIME_VALUES) RETURN NUMBER;

FUNCTION XX_GET_STRING_VALUE (SQLS VARCHAR2,R_VALUES IN OUT RUNTIME_VALUES) RETURN VARCHAR2;

FUNCTION XX_PADING_WITH_STR_PAD_DIR_LEN(STR VARCHAR2, PAD VARCHAR2, DIR VARCHAR2 ,LEN NUMBER) RETURN VARCHAR2;

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
          TOP_AMOUNT        NUMBER  );

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
          LOGGED_USER       NUMBER );
END;
/

