CREATE OR REPLACE PACKAGE BODY BOLINF.XX_AP_EFT_FORMATS_PKG
IS

CURSOR c_checks return t_checks IS
SELECT CH.CHECK_ID
      ,CH.DOC_SEQUENCE_VALUE
      ,ch.check_number
      ,CH.AMOUNT
      ,CH.CHECK_DATE
      ,CH.VENDOR_NAME
      ,CH.ATTRIBUTE14 SEND_STATUS
      ,SS.VENDOR_SITE_CODE
  FROM APPS.AP_CHECKS_ALL CH
      ,APPS.AP_SUPPLIER_SITES_ALL SS
 WHERE 1=1
   AND CH.VENDOR_SITE_ID = SS.VENDOR_SITE_ID
   AND CH.PAYMENT_DOCUMENT_ID = g_PAY_DOCUMENT
   AND TRUNC(CH.CHECK_DATE) >= TRUNC(g_START_DATE)
   AND TRUNC(CH.CHECK_DATE) <= TRUNC(g_END_DATE  )
   AND CH.CHECK_NUMBER >= NVL(g_DOC_INI,CH.CHECK_NUMBER)
   AND CH.CHECK_NUMBER <= NVL(g_DOC_FIN,CH.CHECK_NUMBER)
   AND CH.AMOUNT between NVL(g_BASE_AMOUNT ,CH.AMOUNT)
   and NVL(g_TOP_AMOUNT  ,CH.AMOUNT)
   AND NVL(CH.ATTRIBUTE14,k_NEW) = g_STATUS_CHECK
   AND CH.VOID_DATE IS NULL;

procedure open_file  is
begin
    
    w_file_name := w_file_name || TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS');
    w_file_out := UTL_FILE.FOPEN (w_file_dir, w_file_name || w_file_ext, 'w',32767);
    fnd_file.put_line(fnd_file.log,'Opening File');
    w_init_file := true;
EXCEPTION
   WHEN OTHERS THEN
             UTL_FILE.FCLOSE(w_file_out);
            fnd_file.put_line(fnd_file.log,'open_file Error Message Is: '||SQLERRM);
end;

procedure close_file is
    begin
    UTL_FILE.FCLOSE(w_file_out);
    w_init_file := false;
    EXCEPTION
   WHEN OTHERS THEN
             UTL_FILE.FCLOSE(w_file_out);
            fnd_file.put_line(fnd_file.log,'close_file Error Message Is: '||SQLERRM);
end;

procedure PUTLINE(WHICH in number, BUFF in varchar2) is
begin
   if WHICH = FND_FILE.LOG then
      fnd_file.put_line(WHICH, BUFF);
    elsif WHICH = FND_FILE.OUTPUT then
      fnd_file.put_line(WHICH, BUFF);
    elsif WHICH = w_dbms then
        DBMS_OUTPUT.PUT_LINE(BUFF);
    elsif WHICH = w_file then
        if(w_init_file) then
            utl_file.put_line(w_file_out, convert(BUFF, 'WE8ISO8859P1', 'UTF8') );
            utl_file.fflush(w_file_out);
        else
            open_file;
        end if;
   end if;
   exception
      WHEN OTHERS THEN
             UTL_FILE.FCLOSE(w_file_out);
            fnd_file.put_line(fnd_file.log,'PUTLINE Error Message Is: '||SQLERRM);
end;

 
PROCEDURE UPDATE_PROCESS_CHECKS IS

BEGIN
    BEGIN
        for x in c_checks loop
            UPDATE AP_CHECKS_ALL CH
               SET CH.ATTRIBUTE14 = 'NEW'
             WHERE ch.check_id = x.check_id;
        end loop;
        COMMIT;
    EXCEPTION
    WHEN OTHERS THEN 
    ROLLBACK;
    END;
    
END;
 

 function bool_to_char(p_bool in boolean) 
return varchar2
is
  l_chr  varchar2(1) := null;
begin
    l_chr := (CASE p_bool when true then 'Y' ELSE 'N' END);
    return(l_chr);
end;

 /*
    ############################################################
        FUNCION LOG_REPORT_DETAILS 
    ############################################################
 */

    
procedure report_subrequest is

v_request_id NUMBER;
begin
    
    v_request_id    := APPS.FND_REQUEST .SUBMIT_REQUEST
                   ('XBOL'
                   ,'XX_AP_PAY_REG'
                   ,''
                   ,''
                   ,FALSE
                   ,g_BANK_ID
                   ,g_BANK_ACC
                   ,g_PAY_DOCUMENT
                   ,to_char(g_START_DATE,fnd_date.canonical_DT_mask)
                   ,to_char(g_END_DATE,fnd_date.canonical_DT_mask)
                   ,g_CHECKRUN_ID
                   ,g_DOC_INI
                   ,g_DOC_FIN
                   ,g_BASE_AMOUNT
                   ,g_TOP_AMOUNT
                   ,chr(0)
                  );
                  
    putline(w_log,'Report_subrequest submitted. ID = ' || v_request_id);
    commit ;
exception
when others then
    putline(w_log,'Exception ' || sqlerrm);
end;

PROCEDURE GET_TRXAMOUNT_AND_TRXLINES  IS
BEGIN 
    v_TRX_LINES := 0;
    v_SUM_TRANS := 0;
    for x in c_checks loop
        v_TRX_LINES := v_TRX_LINES + 1;
        v_SUM_TRANS := v_SUM_TRANS + x.AMOUNT;
    end loop;                  
END;                                   

 
procedure  LOG_REPORT_DETAILS (p_wich number) IS
          
V_BANK_NAME       VARCHAR2(400);
V_BRANCH_NAME     VARCHAR2(400);
V_PAYMENT_DOC     VARCHAR2(400);
V_BANK_ACC_NAME   VARCHAR2(400);
V_BATCH_NAME      VARCHAR2(400);
V_TRX_COUNTER        NUMBER;
V_SUM_OF_TRX         NUMBER;
LINE              VARCHAR2(500);

begin 

    GET_TRXAMOUNT_AND_TRXLINES;
    
    PUTLINE(W_LOG,'+---------------------------------------------------------------------------+');
    PUTLINE(W_LOG,'Begin Log_Report_Details Values ');
    PUTLINE(W_LOG,'+---------------------------------------------------------------------------+');
    
    BEGIN
        PUTLINE(W_LOG,' PARAMETERS_P.BANK_ID:'|| to_char(g_BANK_ID));
        PUTLINE(W_LOG,' PARAMETERS_P.BANK_ACC:'|| to_char(g_BANK_ACC));
        PUTLINE(W_LOG,' PARAMETERS_P.PAY_DOCUMENT:'|| to_char(g_PAY_DOCUMENT));
    select b.BANK_NAME
    INTO V_BANK_NAME 
    FROM APPS.ce_banks_v b
    where b.BANK_PARTY_ID = g_BANK_ID;

    select ba.BANK_ACCOUNT_NAME
      INTO V_BANK_ACC_NAME 
      from APPS.ce_bank_accounts      ba
     where ba.BANK_ACCOUNT_ID = g_BANK_ACC;

    select dc.PAYMENT_DOCUMENT_NAME
      INTO V_PAYMENT_DOC
      FROM APPS.ce_payment_documents dc
     where dc.PAYMENT_DOCUMENT_ID = g_PAY_DOCUMENT;
        
    EXCEPTION
    when others then 
        PUTLINE(W_LOG,'Unexpected Error');
        PUTLINE(W_LOG,'SQLERRM : '||SQLERRM);
    END;
    
    PUTLINE(W_LOG,'+---------------------------------------------------------------------------+');
    PUTLINE(W_LOG,'End Log_Report_Details Values ');
    PUTLINE(W_LOG,'+---------------------------------------------------------------------------+');
    
    PUTLINE(p_wich,'');
    PUTLINE(p_wich,'Payment Register ');
    PUTLINE(p_wich,'BANK              : '||V_BANK_NAME );
    PUTLINE(p_wich,'BANK ACCOUNT NAME : '||V_BANK_ACC_NAME  );
    PUTLINE(p_wich,'PAYMENT DOCUMENT  : '||V_PAYMENT_DOC);
    PUTLINE(p_wich,'CURRENT DATE-TIME : '||fnd_date.date_to_displayDT(sysdate) );
    
    IF g_CHECKRUN_ID IS NOT NULL THEN
    PUTLINE(p_wich,'CHECKRUN NAME     : '||V_BATCH_NAME);
    END IF;
    PUTLINE(p_wich,'  ');
    
    LINE:='';
    LINE := LINE ||'  ' || RPAD('CHECK NUMBER'   ,12, ' ');
    LINE := LINE ||'  ' || RPAD('CHECK DATE'     ,15, ' ');
    LINE := LINE ||'  ' || RPAD('SUPPLIER NAME'  ,50,' ');
    LINE := LINE ||'  ' || RPAD('VENDOR SITE'    ,15, ' ');
    LINE := LINE ||'  ' || LPAD('AMOUNT'         ,15, ' ');
    --LINE := LINE ||'  ' || RPAD('CHECK STATUS'   ,15, ' ');
    LINE := LINE ||'  ' || RPAD('SEND STATUS'    ,15, ' ');
    
    PUTLINE(p_wich,LINE);

        FOR C IN c_checks  LOOP
            LINE:='';
            LINE := LINE ||'  ' || LPAD(TO_CHAR(NVL(C.CHECK_NUMBER,0))             ,12,' ');
            LINE := LINE ||'  ' || RPAD(fnd_date.date_to_displaydate(C.CHECK_DATE) ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_NAME,' ')                     ,50,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_SITE_CODE,' ')                ,15,' ');
            LINE := LINE ||'  ' || LPAD(TO_CHAR(C.AMOUNT,'999,999,999.99')         ,15,' ');
            --LINE := LINE ||'  ' || RPAD(NVL(C.CHECK_STATUS,' ')                    ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.SEND_STATUS,' ')                    ,15,' ');
            PUTLINE(p_wich,LINE);
        END LOOP;
       
    PUTLINE(p_wich,lpad('-',150,'-'));
    PUTLINE(p_wich,'  COUNT '||LPAD( TO_CHAR(v_TRX_LINES),6,' ') || rpad(' ',88,' ')  ||  LPAD(TO_CHAR(v_SUM_TRANS,'999,999,999.99'),15,' ')  );

end;
 
/*
    #####################################################
    FUNCIONES PARA OBTENER VALORES
    #####################################################

*/


  FUNCTION GET_DATE_VALUE (p_cur curtype) RETURN date IS
    date_VAL date;
    BEGIN
        FETCH p_cur  INTO  date_VAL;
    RETURN(date_VAL);
    EXCEPTION
    WHEN OTHERS THEN
          IF p_cur%ISOPEN THEN
          CLOSE p_cur;
          END IF;        
        putline(w_log,'Error fetching date '||sqlerrm);
        RETURN (sysdate);
    END;

  FUNCTION GET_NUMBER_VALUE (p_cur curtype) RETURN NUMBER IS
    NUMBER_VAL NUMBER;
    BEGIN
        FETCH p_cur  INTO  NUMBER_VAL;
        
    RETURN(NUMBER_VAL);

    EXCEPTION
    WHEN OTHERS THEN
          IF p_cur%ISOPEN THEN
          CLOSE p_cur;
          END IF;
        
        putline(w_log,'Error fetching number '||sqlerrm);
        RETURN (0);
    END GET_NUMBER_VALUE;


  FUNCTION GET_string_VALUE (p_cur curtype) RETURN varchar2 IS
    string_VAL varchar2(1000);
    BEGIN
        FETCH p_cur  INTO  string_VAL;
    RETURN(string_VAL);

    EXCEPTION
    WHEN OTHERS THEN
          IF p_cur%ISOPEN THEN
          CLOSE p_cur;
          END IF;
         putline(w_log,'Error fetching string '||sqlerrm);
        RETURN (0);
    END GET_string_VALUE;


    procedure bind_variables_num(p_curid number, p_var_name varchar2, p_var_num number ) is
    begin
        DBMS_SQL.BIND_VARIABLE(p_curid,p_var_name, p_var_num);
    exception when unbound_variable then
        null;
    end;

    procedure bind_variables_str(p_curid number, p_var_name varchar2, p_var_str varchar2 ) is
    begin
        DBMS_SQL.BIND_VARIABLE(p_curid,p_var_name, p_var_str);
    exception when unbound_variable then
        null;
    end;
    
    procedure bind_variables_date(p_curid number, p_var_name varchar2, p_var_date date ) is
    begin
        DBMS_SQL.BIND_VARIABLE(p_curid,p_var_name, p_var_date);
    exception when unbound_variable then
        null;
    end;

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
        RETURN ('');
    END;


/* 
   #############################################################
        FUNCION XX_GENERATE_VALUE
        PROPOCITO : CREAR EL VALOR DE CADA CAMPO
   ##############################################################
*/

FUNCTION GENERATE_VALUE (  SQLST      VARCHAR2   --1
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
                            )RETURN     VARCHAR2 IS

    OUT_STR    VARCHAR2(4000);
    DATE_VAL   DATE;
    NUMBER_VAL NUMBER;
    SQL_STATEMENT VARCHAR2(4000);
    PAD_CHARACTER VARCHAR2(1);
    DELIMIT_CHAR VARCHAR2(1);
    CONSTANT_VALUE VARCHAR2(4000);
    
    curid           INTEGER;
    stmt_str        VARCHAR2(200);
    src_cur         curtype;
    ret number;
    flag_ok_cursor varchar2(1) := 'S';
begin



        CASE TYPE_VAL

        WHEN 'DINAMIC' THEN
            SQL_STATEMENT := SQLST;
            begin
                -- Opening and Parsing Cursor
                begin
                    curid := DBMS_SQL.OPEN_CURSOR;
                    DBMS_SQL.PARSE(curid,SQL_STATEMENT, DBMS_SQL.NATIVE);
                exception when others then
                    flag_ok_cursor := 'E';
                    begin
                      IF src_cur%ISOPEN THEN CLOSE src_cur;END IF;
                      exception when others then putline(w_log,'error while clossing cursor => Opening and Parsing Cursor   : '||sqlerrm);
                    end;
                end;
                
                --Binding Variables
                if flag_ok_cursor = 'S' then
                
                    IF  CHECK_ID IS NOT NULL THEN
                        bind_variables_num(curid,':IDCHECK',CHECK_ID);
                    END IF;
                    
                    IF  INVOICE_ID IS NOT NULL THEN
                        bind_variables_num(curid,':INVOICEID',INVOICE_ID);
                    END IF;
                    
                    IF  G_PAY_DOCUMENT IS NOT NULL THEN
                        bind_variables_num(curid,':PAY_DOCUMENT',G_PAY_DOCUMENT);
                    END IF;
                    
                    IF  G_BASE_AMOUNT IS NOT NULL THEN
                        bind_variables_num(curid,':BASE_AMOUNT',G_BASE_AMOUNT);
                    END IF;
                    
                    IF  G_TOP_AMOUNT IS NOT NULL THEN
                        bind_variables_num(curid,':TOP_AMOUNT',G_TOP_AMOUNT);
                    END IF;
                    
                    IF  G_DOC_INI IS NOT NULL THEN
                        bind_variables_num(curid,':P_DOC_INI',G_DOC_INI);
                    END IF;
                    
                    IF  G_DOC_FIN IS NOT NULL THEN
                        bind_variables_num(curid,':P_DOC_FIN',G_DOC_FIN);
                    END IF;
                    
                    IF  G_START_DATE IS NOT NULL THEN
                        bind_variables_date(curid,':P_START_DATE',to_date(G_START_DATE,'YYYY/MM/DD HH24:MI:SS'));
                    END IF;
                    
                    IF  G_START_DATE IS NOT NULL THEN
                        bind_variables_date(curid,':P_END_DATE',to_date(G_END_DATE,'YYYY/MM/DD HH24:MI:SS'));
                    END IF;

                end if;
                
                -- Excecuting cursor
                if flag_ok_cursor = 'S' then
                    begin
                    ret := DBMS_SQL.EXECUTE(curid);
                    src_cur := DBMS_SQL.TO_REFCURSOR(curid);
                    exception when others then
                        flag_ok_cursor := 'E';
                        begin
                          IF src_cur%ISOPEN THEN CLOSE src_cur;END IF;
                          exception when others then putline(w_log,'error while clossing cursor => Excecuting cursor   : '||sqlerrm);
                        end;
                    end;
                end if;
                
                --putline(w_log,'curid           : '||curid);
            exception 
                when others then 
                
                putline(w_log,'============================');
                putline(w_log,'CHECK_ID->'||to_char(CHECK_ID));
                
                
                putline(w_log,'SQL_STATEMENT   : '||SQL_STATEMENT);
                putline(w_log,'curid           : '||curid);
                putline(w_log,'ERROR           : '||sqlerrm);
                putline(w_log,'ret            : '|| ret);
                flag_ok_cursor  := 'E';
                begin
                  IF src_cur%ISOPEN THEN
                  CLOSE src_cur;
                  END IF;
                  exception when others then
                    putline(w_log,'error while clossing cursor     : '||sqlerrm);
                end;
                
            end;

            if flag_ok_cursor = 'S' then
                CASE DATA_TYPE
                WHEN 'DATE' THEN
                    begin
                        DATE_VAL := GET_DATE_VALUE(src_cur);
                        exception 
                        when others then 
                        putline(w_log,'ERROR DATE_VAL     : '||sqlerrm);
                    end;
                WHEN 'NUMBER' THEN
                    begin
                    NUMBER_VAL := GET_NUMBER_VALUE(src_cur);
                        exception 
                        when others then 
                        putline(w_log,'ERROR number_VAL     : '||sqlerrm);
                    end;
                WHEN 'STRING' THEN
                    begin
                        OUT_STR := GET_STRING_VALUE(src_cur);
                    exception 
                    when others then 
                    putline(w_log,'ERROR string_VAL     : '||sqlerrm);
                    end;
                ELSE
                    OUT_STR := GET_STRING_VALUE(src_cur);
                END CASE;

            else

                putline(w_log,'CHECK_ID      : '||CHECK_ID);
                putline(w_log,'SQL Statement : '||SQL_STATEMENT);

            end if;
            
        WHEN 'CONSTANT' THEN

            CONSTANT_VALUE := CONST_VAL;
            CONSTANT_VALUE := REPLACE (CONSTANT_VALUE,'\T',CHR(9));
            CONSTANT_VALUE := REPLACE (CONSTANT_VALUE,'\E',' ');
            CONSTANT_VALUE := REPLACE (CONSTANT_VALUE,'\N','');
            OUT_STR := CONSTANT_VALUE;

        WHEN 'SEQUENCE1' THEN NUMBER_VAL := v_SEQUENCE1;
        WHEN 'SEQUENCE2' THEN NUMBER_VAL := V_SEQUENCE2;
        WHEN 'SEQUENCE3' THEN NUMBER_VAL := V_SEQUENCE3;
        WHEN 'TRX_LINES' THEN NUMBER_VAL := V_TRX_LINES;
        WHEN 'SUM_TRANS' THEN NUMBER_VAL := V_SUM_TRANS;

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
    
END;


/* 
   #############################################################
        PROCEDIMIENTO  CHECKS_LINE    
        PROPOCITO : UNNA LINEA DE LA TRANSACCION Y/O EL DETALLE DE ESTA
   ##############################################################
*/

PROCEDURE CHECKS_LINE( CHECK_ID  NUMBER ) IS

CURSOR TRX IS
SELECT  DT.DEFINITION_ID
       ,MS.FORMAT_TYPE
       ,chr(MS.ASCII_DELIMITER)  DELIMITER
       ,DT.TYPE_VALUE
       ,DT.CONSTANT_VALUE
       ,DT.SECUENCE
       ,DT.START_POSITION
       ,DT.END_POSITION
       ,DT.DATA_TYPE
       ,DT.FORMAT_MODEL
       --,DT.MAX_VALUE_LENGHT
       ,DT.PADDING_CHARACTER
       ,DT.DIRECTION_PADDING
       ,DT.NEEDS_PADDING
       ,DT.SQL_STATEMENT
  FROM  XX_AP_EFT_FORMAT_DEFINITIONS DT
       ,XX_AP_EFT_FORMATS MS
 WHERE ms.format_id = g_FORMAT_USED
   AND DT.format_id = MS.format_id
   AND MS.ENABLE_FLAG = 'Y'
   AND DT.PART_OF_FILE = k_Body
 ORDER BY DT.SECUENCE ASC;


CURSOR  DETAIL IS
SELECT  DT.DEFINITION_ID
       ,MS.FORMAT_TYPE
       ,CHR(MS.ASCII_DELIMITER) DELIMITER
       ,DT.TYPE_VALUE
       ,DT.CONSTANT_VALUE
       ,DT.SECUENCE
       ,DT.START_POSITION
       ,DT.END_POSITION
       ,DT.DATA_TYPE
       ,DT.FORMAT_MODEL
       --,DT.MAX_VALUE_LENGHT
       ,DT.PADDING_CHARACTER
       ,DT.DIRECTION_PADDING
       ,DT.NEEDS_PADDING
       ,DT.SQL_STATEMENT
  FROM  XX_AP_EFT_FORMAT_DEFINITIONS DT
       ,XX_AP_EFT_FORMATS MS
 where ms.FORMAT_ID = g_FORMAT_USED
   AND DT.FORMAT_ID = MS.FORMAT_ID
   AND DT.PART_OF_FILE = k_Detail
   AND MS.ENABLE_flag = 'Y'
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
    
    FOR Q IN TRX LOOP

    FIELD:= GENERATE_VALUE (
          Q.SQL_STATEMENT        --1
         ,Q.TYPE_VALUE           --2
         ,CHECK_ID               --3
         ,NULL                   --4
         ,Q.DATA_TYPE            --5
         ,Q.FORMAT_MODEL         --6
         ,Q.CONSTANT_VALUE       --7
         ,Q.NEEDS_PADDING        --8
         ,Q.PADDING_CHARACTER    --9
         ,Q.DIRECTION_PADDING    --10
         ,Q.END_POSITION - Q.START_POSITION + 1   --11
         ,Q.FORMAT_TYPE          --12
         ,Q.DELIMITER            --13
          );

    TRX_LINE := TRX_LINE||FIELD;
    --fnd_file.PUT_LINE(fnd_file.OUTPUT,'PART '||PART);
    END LOOP;

    IF F_FORMAT_TYPE = k_delimited THEN
     trx_line :=  substr(trx_line,1,length(trx_line)-1);
    END IF;
    
    PUTLINE(w_file,trx_line );  

    IF f_TRX_DETAIL THEN

        v_SEQUENCE2 := 1;

        FOR W IN INVOICES(CHECK_ID) LOOP

            DETAIL_LINE := '';

            FOR H IN DETAIL  LOOP

            FIELD := GENERATE_VALUE (
                     H.SQL_STATEMENT, --1
                     H.TYPE_VALUE ,     --2
                     CHECK_ID   ,       --3
                     W.INVOICE_ID,      --4
                     H.DATA_TYPE,       --5
                     H.FORMAT_model,    --6
                     H.CONSTANT_VALUE,  --9
                     H.NEEDS_PADDING,   --10
                     H.PADDING_CHARACTER,--11
                     H.DIRECTION_PADDING,       --12
                     H.END_POSITION - H.START_POSITION +1,        --13
                     H.FORMAT_TYPE,      --14
                     H.DELIMITER           --15
            );

            --fnd_file.PUT_LINE(fnd_file.OUTPUT,'PART2 '||PART2);
            DETAIL_LINE := DETAIL_LINE||FIELD;

            END LOOP;


            IF F_FORMAT_TYPE = k_delimited THEN
            DETAIL_LINE := SUBSTR(DETAIL_LINE,1,LENGTH(DETAIL_LINE)-1);
            END IF;

            PUTLINE(w_wich,DETAIL_LINE);
            

            v_SEQUENCE2 := v_SEQUENCE2 + 1;
            v_SEQUENCE3 := v_SEQUENCE3 + 1;

        END LOOP;

    END IF;

    v_SEQUENCE1 := v_SEQUENCE1 + 1;
    v_SEQUENCE3 := v_SEQUENCE3 + 1;
    exception
    WHEN OTHERS THEN
    putline(w_log,'PROCEDURE CHECKS_LINE Message Is: '||SQLERRM);         
END;                       
                      
/* 
   #############################################################
        PROCEDIMIENTO PRINCIPAL 
        PROPOCITO : CREAR LA ESTUCTURA DEL ARCHIVO
   ##############################################################
*/



procedure INITIALIZE (
          BANK_ID           NUMBER,
          BANK_ACC          NUMBER,
          PAY_DOCUMENT      NUMBER,
          START_DATE    VARCHAR2,
          END_DATE      VARCHAR2,
          CHECKRUN_ID       NUMBER,
          P_DOC_INI         NUMBER,
          P_DOC_FIN         NUMBER,
          BASE_AMOUNT       NUMBER,
          TOP_AMOUNT        NUMBER,
          TRANSFER_FTP     varchar2 default 'N' ) is

    CURSOR FORMAT  IS
        SELECT DISTINCT
           MS.FORMAT_ID
          ,CHR(MS.ASCII_DELIMITER) DELIMITER
          --,MS.MAX_VALUE_LENGTH
          ,MS.FORMAT_TYPE
          ,DT.PART_OF_FILE
      FROM  XX_AP_EFT_FORMAT_DEFINITIONS DT
            ,XX_AP_EFT_FORMATS MS
     WHERE ms.FORMAT_ID = g_FORMAT_USED
       AND MS.ENABLE_FLAG = 'Y'
       AND MS.FORMAT_ID = DT.FORMAT_ID;

begin
    
    E_Start_Flag := true;

    G_BANK_ID       := BANK_ID;
    G_BANK_ACC      := BANK_ACC;
    G_PAY_DOCUMENT  := PAY_DOCUMENT; 
    G_START_DATE    := to_date(START_DATE,fnd_date.canonical_DT_mask); 
    G_END_DATE      := to_date(END_DATE,fnd_date.canonical_DT_mask);
    G_BASE_AMOUNT   := BASE_AMOUNT; 
    G_TOP_AMOUNT    := TOP_AMOUNT;
    G_DOC_INI       := P_DOC_INI;
    G_DOC_FIN       := P_DOC_FIN;
    G_CHECKRUN_ID   := CHECKRUN_ID;
    G_STATUS_CHECK  := k_NEW;
        
    begin
        select ms.FORMAT_ID ,   fdc.OUTGOING_DIRECTORY, ms.file_extension
          into g_FORMAT_USED,   w_file_dir            , W_File_Ext
          from XX_AP_EFT_FORMATS ms
              ,apps.CE_PAYMENT_DOCUMENTS dc
              , apps.CE_PAYMENT_DOCUMENTS_DFV fdc
         where dc.PAYMENT_DOCUMENT_ID = PAY_DOCUMENT
           and fdc.rowid = dc.rowid
           AND ms.FORMAT_ID = to_number(fdc.FORMAT_FILE);
    exception when no_data_found then
        E_Error_Code := '1';
         PUTLINE(w_LOG,' Payment Document Does not have an assigned Format '||w_file_dir);
    end;
   
    if TRANSFER_FTP = 'Y' then 
        PUTLINE(w_LOG,' File will be transfer to FTP ');
        begin
           select DIRECTORY_NAME into w_file_dir
            from all_directories 
            where DIRECTORY_NAME = w_file_dir
            ;
        exception when no_data_found then
            E_Error_Code := '1';
            PUTLINE(w_LOG,' Directory Does not exist in DB '||w_file_dir);
            when others then
            PUTLINE(w_LOG,' UnExpected Error all_directories '||SQLerrm);
        end;
        
        if w_file_dir is not null and W_File_Ext is not null  then
            f_transfer_ftp := true;
            open_file;
            W_Wich := w_file;
        else
            f_transfer_ftp := false;
            PUTLINE(w_LOG,' Extention is not Set ');
        end if;
               
    else   
        f_transfer_ftp := false;
        w_wich := w_output;
    end if;
           
    putline(w_log,',BANK_ID         =>'''||BANK_ID||'''');
    putline(w_log,',BANK_ACC        =>'''||BANK_ACC||'''');
    putline(w_log,',PAY_DOCUMENT    =>'''||PAY_DOCUMENT||'''');
    putline(w_log,',START_DATE      =>'''||START_DATE||'''');
    putline(w_log,',END_DATE        =>'''||END_DATE||'''');
    putline(w_log,',CHECKRUN_ID     =>'''||CHECKRUN_ID||'''');
    putline(w_log,',P_DOC_INI       =>'''||P_DOC_INI||'''');
    putline(w_log,',P_DOC_FIN       =>'''||P_DOC_FIN||'''');
    putline(w_log,',BASE_AMOUNT     =>'''||BASE_AMOUNT||'''');
    putline(w_log,',TOP_AMOUNT      =>'''||TOP_AMOUNT||'''');
    putline(w_log,',TRANSFER_FTP     =>'''||TRANSFER_FTP||'''');
        
    FOR R IN FORMAT LOOP
                    
        F_FORMAT_TYPE  := R.FORMAT_TYPE;
        f_DELIMITER       := R.DELIMITER;

        CASE R.PART_OF_FILE
        WHEN 'HEADER' THEN  f_TRX_HEADER := true;
        WHEN 'TRX'    THEN  f_TRX_BODY   := true;
        WHEN 'DETAIL' THEN  f_TRX_DETAIL := true;
        WHEN 'FOOTER' THEN  f_TRX_FOOTER := true;
        ELSE NULL;
        END CASE;

    END LOOP;
                
    putline(w_log,'f_TRX_HEADER       =>' ||bool_to_char( f_TRX_HEADER));
    putline(w_log,'f_TRX_BODY         =>' ||bool_to_char( f_TRX_BODY));
    putline(w_log,'f_TRX_DETAIL       =>' ||bool_to_char( f_TRX_DETAIL));
    putline(w_log,'f_TRX_FOOTER       =>' ||bool_to_char( f_TRX_FOOTER));
    putline(w_log,'F_FORMAT_TYPE      =>' || F_FORMAT_TYPE);
    putline(w_log,'f_DELIMITER        =>' || f_DELIMITER);
    putline(w_log,'g_FORMAT_USED      =>' || g_FORMAT_USED);
    
    
    GET_TRXAMOUNT_AND_TRXLINES;
    
    IF g_CHECKRUN_ID IS NULL THEN
        IF     g_START_DATE   IS NULL
            OR g_END_DATE     IS NULL
            OR g_PAY_DOCUMENT   IS NULL THEN 
            PUTLINE(w_LOG,'Unexpected : Not enough parameters to continue');
            e_ERROR_CODE := '1';
        end if;
    end if;

    if g_format_used is null then
        E_Error_Code := '1';
        putline(w_log,'Unexpected : This payment Document Does not have a format asosiated with.');
    end if;
    
    IF v_TRX_LINES = 0 THEN
        putline(w_log,'Warning : Parameters did not retrieve any data');
        e_ERROR_CODE := '1';
    END IF;
    
end;


procedure main (
          ERRBUF     OUT  VARCHAR2,
          RETCODE    OUT  VARCHAR2,
          BANK_ID           NUMBER,
          BANK_ACC          NUMBER,
          PAY_DOCUMENT      NUMBER,
          START_DATE    VARCHAR2,
          END_DATE      VARCHAR2,
          CHECKRUN_ID       NUMBER,
          P_DOC_INI         NUMBER,
          P_DOC_FIN         NUMBER,
          BASE_AMOUNT       NUMBER,
          TOP_AMOUNT        NUMBER,
          TRANSFER_FTP      varchar2,
          debug_flag  Varchar2 default '1'
) IS
    

    FIELD       VARCHAR2(4000);
    LINE        VARCHAR2(4000);
    


CURSOR SUMARY(PART VARCHAR2 ) IS
    SELECT  DT.DEFINITION_ID
           ,MS.FORMAT_TYPE
           ,CHR(MS.ASCII_DELIMITER) DELIMITER
           ,DT.TYPE_VALUE
           ,DT.CONSTANT_VALUE
           ,DT.SECUENCE
           ,DT.DATA_TYPE
           ,DT.FORMAT_MODEL
           --,DT.MAX_VALUE_LENGHT
           ,DT.END_POSITION
           ,DT.START_POSITION
           ,DT.PADDING_CHARACTER
           ,DT.DIRECTION_PADDING
           ,DT.NEEDS_PADDING
           ,DT.SQL_STATEMENT
      FROM  XX_AP_EFT_FORMAT_DEFINITIONS DT
           ,XX_AP_EFT_FORMATS MS
     WHERE 1=1
       and ms.FORMAT_ID = g_FORMAT_USED
       AND DT.FORMAT_ID = MS.FORMAT_ID
       AND DT.PART_OF_FILE = PART
       AND MS.ENABLE_FLAG = 'Y'
     ORDER BY DT.SECUENCE ASC;

    BEGIN
        if debug_flag != '1' then
            W_Log := w_dbms;
        end if;

        putline(w_log,'Start process log');
        putline(w_log,'+---------------------------------------------------------------------------+');

        --+ set Global Varibles for formating and Output
        --+ Checks if minimun requirements are place, also the correct configuration

        INITIALIZE (
                    BANK_ID
                   ,BANK_ACC
                   ,PAY_DOCUMENT
                   ,START_DATE
                   ,END_DATE
                   ,CHECKRUN_ID
                   ,P_DOC_INI
                   ,P_DOC_FIN
                   ,BASE_AMOUNT
                   ,TOP_AMOUNT
                   ,TRANSFER_FTP
                   );

        IF E_Start_Flag THEN
            
            IF f_TRX_HEADER THEN

                FOR L IN SUMARY(k_Header) LOOP

                    FIELD := GENERATE_VALUE (
                             L.SQL_STATEMENT,
                             L.TYPE_VALUE ,
                             NULL,
                             NULL,
                             L.DATA_TYPE,
                             L.FORMAT_MODEL,
                             L.CONSTANT_VALUE,
                             L.NEEDS_PADDING,
                             L.PADDING_CHARACTER,
                             L.DIRECTION_PADDING,
                             L.END_POSITION - L.START_POSITION + 1,
                             L.FORMAT_TYPE,
                             L.DELIMITER
                            );

                         LINE := LINE||FIELD;
                END LOOP;

                IF F_FORMAT_TYPE = k_delimited THEN
                LINE := SUBSTR(LINE,1,LENGTH(LINE)-1);
                END IF;

                PUTLINE(w_wich,LINE);

            END IF;

            IF f_TRX_BODY THEN
                
                v_SEQUENCE1 := 1;

                for i in c_checks loop
                    CHECKS_LINE( CHECK_ID  => i.CHECK_ID );
                end loop;

            END IF;


            IF f_TRX_FOOTER THEN

                FOR L IN SUMARY(k_TRAILER) LOOP

                    FIELD := GENERATE_VALUE (
                         L.SQL_STATEMENT,
                         L.TYPE_VALUE ,
                         NULL,
                         NULL,
                         L.DATA_TYPE,
                         L.FORMAT_MODEL,
                         L.CONSTANT_VALUE,
                         L.NEEDS_PADDING,
                         L.PADDING_CHARACTER,
                         L.DIRECTION_PADDING,
                         L.END_POSITION - L.START_POSITION +1,
                         L.FORMAT_TYPE,
                         L.DELIMITER
                            );

                         LINE := LINE||FIELD;
                END LOOP;

                IF f_FORMAT_TYPE = K_DELIMITED THEN
                LINE := SUBSTR(LINE,1,LENGTH(LINE)-1);
                END IF;

                PUTLINE(w_wich,LINE);

            END IF;
               
        END IF;

       
        IF e_START_FLAG  THEN

            
            if f_transfer_ftp then
            null;
           UPDATE_PROCESS_CHECKS;
            
           end if;
           
            report_subrequest; --+ This Raise a Report of The payments Just Send
            
          
        end if;
        
        if W_Init_File then
        close_file;
        end if;
        
        putline(w_log,'+---------------------------------------------------------------------------+');
        putline(w_log,'End process log');
        
    EXCEPTION
        WHEN OTHERS THEN
            putline(w_log,'Main Error Message Is: '||SQLERRM);
      retcode   := '2';
      errbuf    := SQLERRM;
     ROLLBACK;

    END;
    
    
procedure REPORT (
          ERRBUF     OUT  VARCHAR2,
          RETCODE    OUT  VARCHAR2,
          BANK_ID           NUMBER,
          BANK_ACC          NUMBER,
          PAY_DOCUMENT      NUMBER,
          START_DATE    VARCHAR2,
          END_DATE      VARCHAR2,
          CHECKRUN_ID       NUMBER,
          P_DOC_INI         NUMBER,
          P_DOC_FIN         NUMBER,
          BASE_AMOUNT       NUMBER,
          TOP_AMOUNT        NUMBER
) IS
    
    BEGIN

        INITIALIZE (
              BANK_ID,
              BANK_ACC,
              PAY_DOCUMENT,
              START_DATE ,
              END_DATE,
              CHECKRUN_ID ,
              P_DOC_INI,
              P_DOC_FIN,
              BASE_AMOUNT,
              TOP_AMOUNT,
              'N');
        
       LOG_REPORT_DETAILS (w_output);

        retcode := '0';

    EXCEPTION
         WHEN OTHERS
         THEN
      retcode := '2';
      errbuf := SQLERRM;
     ROLLBACK;

    END;

    


PROCEDURE XX_UPDATE_CHECKS_STATUS (
          ERRBUF     OUT  VARCHAR2,
          RETCODE    OUT  VARCHAR2,
          PAY_DOCUMENT      NUMBER,
          P_START_DATE    VARCHAR2,
          P_END_DATE      VARCHAR2,
          P_DOC_INI         NUMBER,
          P_DOC_FIN         NUMBER,
          BASE_AMOUNT       NUMBER,
          TOP_AMOUNT        NUMBER,
          SET_STATUS      VARCHAR2
          ) IS

    ROWS_UPDATED NUMBER;   
    aux_rows     number;
    USER_GRANTED_ID  NUMBER;    
    
BEGIN



        begin
            select  b.BANK_PARTY_ID,bu.BANK_ACCOUNT_ID
              into g_bank_id , g_BANK_ACC
        from  apps.ce_banks_v b ,apps.ce_bank_acct_uses_all bu ,ce_bank_accounts ba , apps.ce_payment_documents dc
         where bu.BANK_ACCOUNT_ID = ba.BANK_ACCOUNT_ID
           and ba.BANK_ID  = b.BANK_PARTY_ID
           and dc.INTERNAL_BANK_ACCOUNT_ID = bu.BANK_ACCOUNT_ID
           and dc.PAYMENT_DOCUMENT_ID = PAY_DOCUMENT
            ;
        exception
        when others then
        putline(w_log,'Error Retrieving Parameters ');
        putline(w_log,'SQLERRM: '||sqlerrm );
        end;
        
        G_PAY_DOCUMENT := PAY_DOCUMENT;
        G_START_DATE := to_date(P_START_DATE,fnd_date.canonical_DT_mask); 
        G_END_DATE   := to_date(P_END_DATE,fnd_date.canonical_DT_mask);
        G_BASE_AMOUNT  := BASE_AMOUNT; 
        G_TOP_AMOUNT   := TOP_AMOUNT;
        G_DOC_INI    := P_DOC_INI;
        G_DOC_FIN    := P_DOC_FIN;
        G_STATUS_CHECK := k_NEW;
        
    begin
        
        for i in c_checks loop
            UPDATE AP_CHECKS_ALL CH
           SET CH.ATTRIBUTE14 = SET_STATUS
         WHERE ch.check_id = i.check_id;
         aux_rows:= SQL%Rowcount;
         ROWS_UPDATED := ROWS_UPDATED +aux_rows; 
        end loop;

        fnd_file.Put_Line(fnd_file.output,'Checks Updated : '||to_char(ROWS_UPDATED,'99999999'));
        RETCODE  := '0';
        COMMIT;
        LOG_REPORT_DETAILS(w_output);
        
    end;

END;

END;
/
