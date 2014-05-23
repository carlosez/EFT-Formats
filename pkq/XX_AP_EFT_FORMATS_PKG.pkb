CREATE OR REPLACE PACKAGE BODY BOLINF.XX_AP_EFT_FORMATS_PKG
IS

CURSOR c_checks return t_checks IS
SELECT CH.CHECK_ID
      ,CH.DOC_SEQUENCE_VALUE
      ,ch.check_number
      ,CH.AMOUNT
      ,CH.CHECK_DATE
      ,CH.VENDOR_NAME
      ,status.FLEX_VALUE_MEANING SEND_STATUS
      ,SS.VENDOR_SITE_CODE
  FROM APPS.AP_CHECKS_ALL CH
      ,APPS.AP_SUPPLIER_SITES_ALL SS
      ,apps.AP_CHECKS_ALL_DFV chdfv
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
   AND CH.PAYMENT_DOCUMENT_ID = g_PAY_DOCUMENT
   AND TRUNC(CH.CHECK_DATE) >= TRUNC(g_START_DATE)
   AND TRUNC(CH.CHECK_DATE) <= TRUNC(g_END_DATE  )
   AND CH.CHECK_NUMBER >= NVL(g_DOC_INI,CH.CHECK_NUMBER)
   AND CH.CHECK_NUMBER <= NVL(g_DOC_FIN,CH.CHECK_NUMBER)
   AND CH.AMOUNT between NVL(g_BASE_AMOUNT ,CH.AMOUNT)
   and NVL(g_TOP_AMOUNT  ,CH.AMOUNT)
   and status.FLEX_VALUE = nvl(CHDFV.eft_status,'NEW')
   and ch.rowid = chdfv.rowid
   --AND NVL(CH.ATTRIBUTE14,k_NEW) in ( k_new, g_STATUS_CHECK )
   AND CH.VOID_DATE IS NULL;


CURSOR C_FILE ( P_PART VARCHAR2 ) RETURN T_file IS
SELECT  MS.FORMAT_TYPE                      --+ 1
       ,chr(MS.ASCII_DELIMITER)  DELIMITER  --+ 2
       ,DT.TYPE_VALUE                       --+ 3
       ,DT.CONSTANT_VALUE                   --+ 4
       ,DT.SECUENCE                         --+ 5
       ,DT.START_POSITION                   --+ 6
       ,DT.END_POSITION                     --+ 7
       ,DT.DATA_TYPE                        --+ 8
       ,DT.FORMAT_MODEL                     --+ 9
       ,chr( nvl( DT.PADDING_CHARACTER, 32  )) PADDING_CHARACTER --+ 10
       ,decode(FORMAT_TYPE , 'DELIMITED', DT.DIRECTION_PADDING , 'FIXED_WIDTH',  decode( nvl(DT.DIRECTION_PADDING,'NONE'),'NONE','RIGTH',DT.DIRECTION_PADDING )  ) DIRECTION_PADDING                --+ 11
       ,decode(FORMAT_TYPE , 'FIXED_WIDTH','Y', decode(DT.DIRECTION_PADDING,'NONE','N','RIGTH','Y', 'LEFT', 'Y') )NEEDS_PADDING --+ 12
       ,DT.SQL_STATEMENT                     --+ 13
  FROM  XX_AP_EFT_FORMAT_DEFINITIONS DT
       ,XX_AP_EFT_FORMATS MS
 WHERE ms.format_id = g_FORMAT_USED
   AND DT.format_id = MS.format_id
   AND MS.ENABLE_FLAG = 'Y'
   AND DT.PART_OF_FILE = P_PART
 ORDER BY DT.SECUENCE ASC;


 function bool_to_char(p_bool in boolean)  return varchar2
is
  l_chr  varchar2(1) := null;
begin
    l_chr := (CASE p_bool when true then 'Y' ELSE 'N' END);
    return(l_chr);
end;


procedure open_file  is
begin
    
    putline(w_log,'Call of function Opening File ');
    putline(w_log,'w_file_dir       '||w_file_dir);
    putline(w_log,'w_file_name      '||w_file_name);
    putline(w_log,'w_file_ext       '||w_file_ext);
    putline(w_log,'w_init_file      '||bool_to_char(w_init_file));
    IF NOT w_init_file THEN
        w_file_name := w_file_name || TO_CHAR(SYSDATE,'_YYYY-MM-DD_HH24-MI-SS');
        w_file_out := UTL_FILE.FOPEN (w_file_dir, w_file_name || w_file_ext, 'w',32767);
        w_init_file := true;
        DBMS_OUTPUT.PUT_LINE('# Opening File #');
        putline(w_log,'w_init_file change to  '||bool_to_char(w_init_file));
        
    END IF;
    
EXCEPTION
   WHEN OTHERS THEN
             UTL_FILE.FCLOSE(w_file_out);
            DBMS_OUTPUT.PUT_LINE(' # Error Opening File '|| SQLERRM );
            putline(w_log,' # Error Opening File '|| SQLERRM );
end;

procedure close_file is
    begin
    
    putline(w_log,'Call of function Close File');
    putline(w_log,'w_init_file      '||bool_to_char(w_init_file));
    
    UTL_FILE.FCLOSE(w_file_out);
    w_init_file := false;
    DBMS_OUTPUT.PUT_LINE('# Closing File #');
    EXCEPTION
   WHEN OTHERS THEN
             UTL_FILE.FCLOSE(w_file_out);
            fnd_file.put_line(fnd_file.log,'close_file Error Message Is: '||SQLERRM);
end;

--procedure PUT(WHICH in number, BUFF in varchar2) is

procedure PUT(WHICH in number, BUFF in varchar2) is
begin
    if      WHICH = FND_FILE.LOG then
                fnd_file.put(WHICH, BUFF);
    elsif   WHICH = FND_FILE.OUTPUT then
                fnd_file.put(WHICH, BUFF);
    elsif   WHICH = w_dbms then
                DBMS_OUTPUT.PUT_LINE(BUFF);
    elsif   WHICH = w_file then
        if(w_init_file) then
            utl_file.put( w_file_out  , convert(BUFF  ,  'WE8ISO8859P1', 'UTF8')   );
            utl_file.fflush(w_file_out);
            putline(w_log,'File is Close : '||BUFF );
        else
            putline(w_log,'File is Close : '||BUFF );
        end if;
    end if;
   exception
      WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('error abriendo archivo ' ||SQLERRM  );
             if F_Transfer_Ftp then
             close_file;
             end if;
            fnd_file.put_line(fnd_file.log,'PUTLINE Error Message Is: '||SQLERRM);
end;


procedure PUTLINE(WHICH in number, BUFF in varchar2) is
begin
    if      WHICH = FND_FILE.LOG then
                fnd_file.put_line(WHICH, BUFF);
    elsif   WHICH = FND_FILE.OUTPUT then
                fnd_file.put_line(WHICH, BUFF);
    elsif   WHICH = w_dbms then
                DBMS_OUTPUT.PUT_LINE(BUFF);
    elsif   WHICH = w_file then
        if(w_init_file) then
            utl_file.put( w_file_out  , convert(BUFF  ,  'WE8ISO8859P1', 'UTF8')   );
            utl_file.fflush(w_file_out);
            putline(w_log,'File is Close : '||BUFF );
        else
            putline(w_log,'File is Close : '||BUFF );
        end if;
    end if;
   exception
      WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('error abriendo archivo ' ||SQLERRM  );
             if F_Transfer_Ftp then
             close_file;
             end if;
            fnd_file.put_line(fnd_file.log,'PUTLINE Error Message Is: '||SQLERRM);
end;
 


/*****************************************************************
                   Levantar Report Sub Request  
******************************************************************/

procedure report_subrequest is
v_request_id NUMBER;
begin
    v_request_id    := APPS.FND_REQUEST .SUBMIT_REQUEST
                   ('XBOL'
                   ,'XX_AP_PAY_REG'
                   ,''
                   ,''
                   ,FALSE
                   ,g_BANK_ACC
                   ,g_PAY_DOCUMENT
                   ,g_DOC_INI
                   ,g_DOC_FIN
                   ,to_char(g_START_DATE,fnd_date.canonical_DT_mask)
                   ,to_char(g_END_DATE,fnd_date.canonical_DT_mask)
                   ,g_BASE_AMOUNT
                   ,g_TOP_AMOUNT
                   ,'N'
                   ,chr(0)
                  );

     putline(w_log,'+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+' || v_request_id);
      putline(w_log,'Report_subrequest submitted. ID = ' || v_request_id);
    putline(w_log,'+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+' || v_request_id);
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

 
procedure  REPORT_DETAILS ( p_wich number)  IS
          
V_BANK_NAME       VARCHAR2(400);
V_BRANCH_NAME     VARCHAR2(400);
V_PAYMENT_DOC     VARCHAR2(400);
V_BANK_ACC_NAME   VARCHAR2(400);
V_BATCH_NAME      VARCHAR2(400);
V_TRX_COUNTER        NUMBER;
V_SUM_OF_TRX         NUMBER;
LINE              VARCHAR2(500);


    TL_REPORT_NAME               Varchar2(250);
    TL_BANK                      Varchar2(250);
    TL_BANK_ACCOUNT              Varchar2(250);
    TL_PAYMENT_DOCUMENT          Varchar2(250);
    TL_DATE_TIME                 Varchar2(250);
    TL_CHECK_NUMBER              Varchar2(250);
    TL_CHECK_DATE                Varchar2(250);
    TL_SUPPLIER_NAME             Varchar2(250);
    TL_SUPPLIER_SITE             Varchar2(250);
    TL_CHECK_AMOUNT              Varchar2(250);
    TL_SEND_STATUS               Varchar2(250);


    cursor c_titles is
    select fvs.flex_value_set_name 
        ,fv.FLEX_VALUE
        ,fvt.FLEX_VALUE_MEANING
    from apps.fnd_flex_value_sets fvs
        ,apps.fnd_flex_values fv
        ,apps.fnd_flex_values_tl fvt
    where  fvs.flex_value_set_name = 'XX_AP_PAY_REG_TITLE_REPORT'
         and  fvs.FLEX_VALUE_SET_ID= fv.FLEX_VALUE_SET_ID
    and fvt.flex_value_id = fv.flex_value_id
    and LANGUAGE = userenv('lang')
    ;

begin

    GET_TRXAMOUNT_AND_TRXLINES;
    
    PUTLINE(W_LOG,'+---------------------------------------------------------------------------+');
    PUTLINE(W_LOG,'Begin Log_Report_Details Values ');
    PUTLINE(W_LOG,'+---------------------------------------------------------------------------+');
    
    BEGIN
        for x in c_titles loop 
            case x.FLEX_VALUE 
            when 'REPORT_NAME'      then TL_REPORT_NAME         :=   x.FLEX_VALUE_MEANING;
            when 'BANK'             then TL_BANK                :=   x.FLEX_VALUE_MEANING;
            when 'BANK_ACCOUNT'     then TL_BANK_ACCOUNT        :=   x.FLEX_VALUE_MEANING;
            when 'PAYMENT_DOCUMENT' then TL_PAYMENT_DOCUMENT    :=   x.FLEX_VALUE_MEANING;
            when 'DATE_TIME'        then TL_DATE_TIME           :=   x.FLEX_VALUE_MEANING;
            when 'CHECK_NUMBER'     then TL_CHECK_NUMBER        :=   x.FLEX_VALUE_MEANING;
            when 'CHECK_DATE'       then TL_CHECK_DATE          :=   x.FLEX_VALUE_MEANING;
            when 'SUPPLIER_NAME'    then TL_SUPPLIER_NAME       :=   x.FLEX_VALUE_MEANING;
            when 'SUPPLIER_SITE'    then TL_SUPPLIER_SITE       :=   x.FLEX_VALUE_MEANING;
            when 'CHECK_AMOUNT'     then TL_CHECK_AMOUNT        :=   x.FLEX_VALUE_MEANING;
            when 'SEND_STATUS'      then TL_SEND_STATUS         :=   x.FLEX_VALUE_MEANING;
            else null; 
            end case;
        end loop;


        begin
        select  b.BANK_NAME  , ba.BANK_ACCOUNT_NAME, dc.PAYMENT_DOCUMENT_NAME
              into V_BANK_NAME , V_BANK_ACC_NAME, V_PAYMENT_DOC
        from  apps.ce_banks_v b ,apps.ce_bank_acct_uses_all bu ,ce_bank_accounts ba , apps.ce_payment_documents dc
         where bu.BANK_ACCOUNT_ID = ba.BANK_ACCOUNT_ID
           and ba.BANK_ID  = b.BANK_PARTY_ID
           and dc.INTERNAL_BANK_ACCOUNT_ID = bu.BANK_ACCOUNT_ID
           and dc.PAYMENT_DOCUMENT_ID = G_Pay_Document
        ;
            exception
            when others then
                putline(w_log,'Error Retrieving Parameters ');
                putline(w_log,'SQLERRM: '||sqlerrm );
        end;
        
    EXCEPTION
    when others then 
        PUTLINE(W_LOG,'Unexpected Error');
        PUTLINE(W_LOG,'SQLERRM : '||SQLERRM);
    END;
    
    PUTLINE(W_LOG,'+---------------------------------------------------------------------------+');
    PUTLINE(W_LOG,'End Log_Report_Details Values ');
    PUTLINE(W_LOG,'+---------------------------------------------------------------------------+');
    
    PUTLINE(p_wich,'');
    PUTLINE(p_wich,TL_REPORT_NAME);
    PUTLINE(p_wich,RPAD(TL_BANK,18,' ') ||': '||V_BANK_NAME );
    PUTLINE(p_wich,RPAD(TL_BANK_ACCOUNT,18,' ') ||': '||V_BANK_ACC_NAME  );
    PUTLINE(p_wich,RPAD(TL_PAYMENT_DOCUMENT,18,' ') ||': '||V_PAYMENT_DOC);
    PUTLINE(p_wich,RPAD(TL_DATE_TIME,18,' ') ||': '||fnd_date.date_to_displayDT(sysdate) );
    
     PUTLINE(p_wich,'');
    
    LINE:='';
    LINE := LINE ||'  ' || LPAD(TL_CHECK_NUMBER,15, ' ');
    LINE := LINE ||'  ' || RPAD(TL_CHECK_DATE   ,14, ' ');
    LINE := LINE ||'  ' || RPAD(TL_SUPPLIER_NAME,50,' ');
    LINE := LINE ||'  ' || RPAD(TL_SUPPLIER_SITE,15, ' ');
    LINE := LINE ||'  ' || LPAD(TL_CHECK_AMOUNT ,15, ' ');
    LINE := LINE ||'  ' || RPAD(TL_SEND_STATUS   ,15, ' ');
    
    PUTLINE(p_wich,LINE);

        FOR C IN c_checks  LOOP
            LINE:='';
            LINE := LINE ||'  ' || LPAD(TO_CHAR(NVL(C.CHECK_NUMBER,0))             ,15,' ');
            LINE := LINE ||'  ' || RPAD(fnd_date.date_to_displaydate(C.CHECK_DATE) ,14,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_NAME,' ')                     ,50,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_SITE_CODE,' ')                ,15,' ');
            LINE := LINE ||'  ' || LPAD(TO_CHAR(C.AMOUNT,'999,999,999.99')         ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.SEND_STATUS,' ')                    ,15,' ');
            PUTLINE(p_wich,LINE);
        END LOOP;
       
    PUTLINE(p_wich,lpad('-',135,'-'));
    PUTLINE(p_wich,'  COUNT '||LPAD( TO_CHAR(v_TRX_LINES),9,' ') || rpad(' ',87,' ')  ||  LPAD(TO_CHAR(v_SUM_TRANS,'999,999,999.99'),15,' ')  );

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


    procedure bind_variables_num(p_curid number, p_sql_stmt varchar2 , p_var_name varchar2, p_var_num number ) is
    begin
        if p_var_num is not null then
            if instr ( p_sql_stmt , p_var_name ,1,1) > 0 then
                DBMS_SQL.BIND_VARIABLE(p_curid,p_var_name, p_var_num);
            end if;
        end if;
    exception when unbound_variable then
        putline(w_log,'bind_variables_num '|| SQLERRM);
    end;

    procedure bind_variables_str(p_curid number, p_sql_stmt varchar2 , p_var_name varchar2, p_var_str varchar2 ) is
    begin
        if p_var_str is not null then
            if instr ( p_sql_stmt , p_var_name ,1,1) > 0 then
                DBMS_SQL.BIND_VARIABLE(p_curid,p_var_name, p_var_str);
            end if;
        end if;
    exception when unbound_variable then
        null;
    end;
    
    procedure bind_variables_date(p_curid number, p_sql_stmt varchar2 , p_var_name varchar2, p_var_date date ) is
    begin
        if p_var_date is not null then
            if instr ( p_sql_stmt , p_var_name ,1,1) > 0 then
                DBMS_SQL.BIND_VARIABLE(p_curid,p_var_name, p_var_date);
            end if;
        end if;
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

/******************************************************************
        Funcion XX_GENERATE_VALUE
        Pourpose : Crear El Valor De Cada Campo
******************************************************************/



FUNCTION GENERATE_VALUE (     SECUENCE   NUMBER     -- 0
                             ,SQLST      VARCHAR2   --1
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
    curid           INTEGER;
    src_cur         curtype;
    ret number;
    flag_ok_cursor varchar2(1) := 'S';
begin



        CASE TYPE_VAL

        WHEN k_DINAMIC THEN
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

                    bind_variables_num (curid,SQL_STATEMENT,':IDCHECK'      ,CHECK_ID);
                    bind_variables_num (curid,SQL_STATEMENT,':CHECK_ID'     ,CHECK_ID);
                    bind_variables_num (curid,SQL_STATEMENT,':INVOICEID'    ,INVOICE_ID);
                    bind_variables_num (curid,SQL_STATEMENT,':PAY_DOCUMENT' ,G_PAY_DOCUMENT);
                    bind_variables_num (curid,SQL_STATEMENT,':BASE_AMOUNT'  ,G_BASE_AMOUNT);
                    bind_variables_num (curid,SQL_STATEMENT,':TOP_AMOUNT'   ,G_TOP_AMOUNT);
                    bind_variables_num (curid,SQL_STATEMENT,':P_DOC_INI'    ,G_DOC_INI);
                    bind_variables_num (curid,SQL_STATEMENT,':P_DOC_FIN'    ,G_DOC_FIN);
                    bind_variables_date(curid,SQL_STATEMENT,':P_START_DATE' ,G_START_DATE);
                    bind_variables_date(curid,SQL_STATEMENT,':P_END_DATE'   ,G_START_DATE);
                    bind_variables_num (curid,SQL_STATEMENT,':V_TRX_LINES'  ,V_Trx_Lines);
                    bind_variables_num (curid,SQL_STATEMENT,':V_SUM_TRANS'  ,V_Sum_Trans);
                    bind_variables_num (curid,SQL_STATEMENT,':V_SEQUENCE3'  ,V_SEQUENCE3);
                    
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
                
--                putline(w_log,'============================');
--                putline(w_log,'CHECK_ID->'||to_char(CHECK_ID));
--                
--                putline(w_log,'SQL_STATEMENT   : '||SQL_STATEMENT);
--                putline(w_log,'curid           : '||curid);
--                putline(w_log,'ERROR           : '||sqlerrm);
--                putline(w_log,'ret             : '|| ret);
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
--
                putline(w_log,'CHECK_ID      : '||CHECK_ID);
                putline(w_log,'SQL Statement : '||SQL_STATEMENT);
                
            end if;

        WHEN k_CONSTANT THEN

            OUT_STR := CONST_VAL;

        WHEN k_SEQUENCE1 THEN NUMBER_VAL := v_SEQUENCE1;
        WHEN k_SEQUENCE2 THEN NUMBER_VAL := V_SEQUENCE2;
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
                    
--        PUTLINE(W_Log,'-----------------------'  );
--        PUTLINE(W_Log,'SEQ=>'   ||to_char( SECUENCE ) );
--        PUTLINE(W_Log,'LEN=>'   ||to_char( LEN ));
--        PUTLINE(W_Log,'TYP=>'   ||k_fixed);
                
        if len < 1 then
            PUTLINE(W_Log,'*** Longitud es negativa ***' ||to_char( LEN ));
        end if;
        
        IF   NEEDS_PA = 'Y' 
        THEN
            if OUT_STR is null then
               OUT_STR := ' ';
            end if;
--            PUTLINE(W_Log,'IN =>'|| OUT_STR );
--            PUTLINE(W_Log,'LEN=>'|| LEN );
--            PUTLINE(W_Log,'DIR=>'|| PAD_DIR );            
--            PUTLINE(W_Log,'CHR=>'|| PAD_CHAR );
            --PUTLINE(W_Log,'ASC=>'|| ascii(PAD_CHARACTER) );
            
            
            CASE PAD_DIR
            WHEN 'RIGHT' THEN   OUT_STR := RPAD(OUT_STR,LEN,PAD_CHAR);
            WHEN 'LEFT'  THEN   OUT_STR := LPAD(OUT_STR,LEN,PAD_CHAR);
            ELSE 
                                OUT_STR := RPAD(OUT_STR,LEN,PAD_CHAR);
            END CASE;
        END IF;

--        PUTLINE(W_Log,'OUT=>'|| OUT_STR );
        
        IF  TYPE_FILE = k_delimited THEN
            OUT_STR := REPLACE(OUT_STR,DELIMITER,'');
            OUT_STR := OUT_STR || DELIMITER;
        END IF;

        RETURN (OUT_STR);

    EXCEPTION
        WHEN OTHERS THEN
        putline(W_Log,' Error Creating Field ' || sqlerrm );
    RETURN ('');
    
END;
--G_debug_flag

/******************************************************************
        Procedimiento  CHECKS_LINE    
        Purpose         UNNA LINEA DE LA TRANSACCION Y/O EL DETALLE DE ESTA
******************************************************************/

PROCEDURE CHECKS_LINE( CHECK_ID  NUMBER ) IS

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
    
--    putline(w_log,'************************* Begin Process for BODY ************************* ');
    
    FOR Q IN C_FILE ( k_Body ) LOOP

        FIELD:= GENERATE_VALUE (
              Q.SECUENCE             --0
             ,Q.SQL_STATEMENT        --1
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

    END LOOP;

    IF F_FORMAT_TYPE = k_delimited THEN
     trx_line :=  substr(trx_line,1,length(trx_line)-1);
    END IF;
    
    put(w_wich, trx_line);
    
    IF f_TRX_DETAIL THEN

        v_SEQUENCE2 := 1;

        FOR W IN INVOICES(CHECK_ID) LOOP

            DETAIL_LINE := '';
--            putline(w_log,'************************* Begin Process for DETAIL ************************* ');
            FOR H IN C_FILE ( k_Detail )  LOOP
                
            FIELD := GENERATE_VALUE (
                     H.SECUENCE,            --0
                     H.SQL_STATEMENT,       --1
                     H.TYPE_VALUE ,         --2
                     CHECK_ID   ,           --3
                     W.INVOICE_ID,          --4
                     H.DATA_TYPE,           --5
                     H.FORMAT_model,        --6
                     H.CONSTANT_VALUE,      --9
                     H.NEEDS_PADDING,       --10
                     H.PADDING_CHARACTER,   --11
                     H.DIRECTION_PADDING,   --12
                     H.END_POSITION - H.START_POSITION +1,        --13
                     H.FORMAT_TYPE,         --14
                     H.DELIMITER            --15
            );

            --fnd_file.PUT_LINE(fnd_file.OUTPUT,'PART2 '||PART2);
                DETAIL_LINE := DETAIL_LINE||FIELD;

            END LOOP;


            IF F_FORMAT_TYPE = k_delimited THEN
                DETAIL_LINE := SUBSTR(DETAIL_LINE,1,LENGTH(DETAIL_LINE)-1);
            END IF;

            --PUTLINE(w_wich,DETAIL_LINE);
            put(w_wich, DETAIL_LINE);
            
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
                      
/******************************************************************
        PROCEDIMIENTO PRINCIPAL 
        PROPOCITO : CREAR LA ESTUCTURA DEL ARCHIVO
******************************************************************/



Procedure Initialize (
           P_Bank_Id            Number      --+ 1
          ,P_Bank_Acc           Number      --+ 2
          ,P_Pay_Document       Number      --+ 3
          ,P_Format_Used        Number      --+ 4
          ,P_Start_Date         Varchar2    --+ 5
          ,P_End_Date           Varchar2    --+ 6
          ,P_Doc_Ini            Number      --+ 7
          ,P_Doc_Fin            Number      --+ 8
          ,P_Base_Amount        Number      --+ 9
          ,P_Top_Amount         Number      --+ 10
          ,P_Transfer_Ftp       Varchar2    --+ 11
          ,P_Directory          Varchar2    --+ 12
          ,P_Only_Unsent        Varchar2    --+ 13
          ,P_Debug_Flag         Varchar2    --+ 14
                      ) Is

    CURSOR FORMAT  IS
    SELECT DISTINCT
           MS.FORMAT_ID
          ,CHR(MS.ASCII_DELIMITER) DELIMITER
          ,MS.FORMAT_TYPE
          ,DT.PART_OF_FILE
      FROM  XX_AP_EFT_FORMAT_DEFINITIONS DT
           ,XX_AP_EFT_FORMATS MS
     WHERE ms.FORMAT_ID = g_FORMAT_USED
       AND MS.ENABLE_FLAG = 'Y'
       AND MS.FORMAT_ID = DT.FORMAT_ID
       ;

begin
    
    E_Start_Flag := true;

    G_BANK_ACC      := P_Bank_Acc;
    G_PAY_DOCUMENT  := P_Pay_Document;
    G_Format_Used   := P_Format_Used; 
    G_START_DATE    := to_date(P_Start_Date,fnd_date.canonical_DT_mask); 
    G_END_DATE      := to_date(P_End_Date,fnd_date.canonical_DT_mask);
    G_BASE_AMOUNT   := p_BASE_AMOUNT; 
    G_TOP_AMOUNT    := p_TOP_AMOUNT;
    G_DOC_INI       := P_DOC_INI;
    G_DOC_FIN       := P_DOC_FIN;
    

    if P_Debug_Flag != '1' then
        g_Debug_Flag := true;
        W_Log := w_dbms;
        w_WICH := W_File;
        putline(W_Log,'Debug Is Set To 1 ' );
    else
        putline(W_Log,'Debug Is Set To ' || P_Debug_Flag );
        w_WICH := W_File;
    end if;

        
    if      P_Only_Unsent = 'Y' then    G_STATUS_CHECK  := k_NEW;
    elsif   P_Only_Unsent = 'N' then    G_STATUS_CHECK  := K_PRINTED;
    end if;


    begin
        select  ms.file_extension   
          into  W_File_Ext
          from XX_AP_EFT_FORMATS ms
         where ms.FORMAT_ID = P_Format_Used
         ;
    exception when no_data_found then
        E_Error_Code := '1';
         PUTLINE(w_LOG,' Payment Document Does not have an assigned Format '||w_file_dir);
    end;
   
    if p_TRANSFER_FTP = 'Y' then 

        W_File_FTP := P_Directory;
        
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
        
        if w_file_dir is not null  then
            f_transfer_ftp := true;
            open_file;
            W_Wich := w_file;
        else
            f_transfer_ftp := false;
            PUTLINE(w_LOG,' Extention is not Set ');
        end if;
        
    else   
        PUTLINE(w_LOG,'The output will be by default ');
        f_transfer_ftp := false;
        
        if not G_debug_flag then
            w_wich      := w_output;
        else
            w_WICH      := W_File;
            open_file;
        end if;

    end if;
    putline(W_Log,'CODE LOG '|| to_char(W_Log) );
    putline(W_Log,'CODE OUT '|| to_char(w_WICH) );     
 
    FOR R IN FORMAT LOOP
                    
        F_FORMAT_TYPE   := R.FORMAT_TYPE;
        f_DELIMITER     := R.DELIMITER;

        CASE R.PART_OF_FILE
        WHEN k_Header   THEN  f_TRX_HEADER := true;
        WHEN k_Body     THEN  f_TRX_BODY   := true;
        WHEN k_Detail   THEN  f_TRX_DETAIL := true;
        WHEN k_TRAILER  THEN  f_TRX_FOOTER := true;
        ELSE NULL;
        END CASE;

    END LOOP;
                
    
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
    
    
    begin
        select  b.BANK_PARTY_ID,bu.BANK_ACCOUNT_ID
          into g_bank_id , g_BANK_ACC
    from  apps.ce_banks_v b ,apps.ce_bank_acct_uses_all bu ,ce_bank_accounts ba , apps.ce_payment_documents dc
     where bu.BANK_ACCOUNT_ID = ba.BANK_ACCOUNT_ID
       and ba.BANK_ID  = b.BANK_PARTY_ID
       and dc.INTERNAL_BANK_ACCOUNT_ID = bu.BANK_ACCOUNT_ID
       and dc.PAYMENT_DOCUMENT_ID = G_Pay_Document
        ;
    exception
    when others then
        putline(w_log,'Error Retrieving Parameters ');
        putline(w_log,'SQLERRM: '||sqlerrm );
        end;
--    putline(w_log,' k_Header                 => ' ||k_Header );
--    putline(w_log,' k_Body                   => ' ||k_Body );
--    putline(w_log,' k_Detail                 => ' ||k_Detail );
--    putline(w_log,' k_TRAILER                => ' ||k_TRAILER );
--    putline(w_log,' k_delimited              => ' ||k_delimited );
--    putline(w_log,' k_fixed                  => ' ||k_fixed );
--    putline(w_log,' k_NEW                    => ' ||k_NEW );
--    putline(w_log,' K_PRINTED                => ' ||K_PRINTED );
--    putline(w_log,' F_Trx_Header             => ' ||bool_to_char(F_Trx_Header ) );
--    putline(w_log,' F_Trx_Body               => ' ||bool_to_char(F_Trx_Body ) );
--    putline(w_log,' F_Trx_Detail             => ' ||bool_to_char(F_Trx_Detail ) );
--    putline(w_log,' F_Trx_Footer             => ' ||bool_to_char(F_Trx_Footer ) );
--    putline(w_log,' F_FORMAT_TYPE            => ' ||F_FORMAT_TYPE );
--    putline(w_log,' F_Delimiter              => ' ||F_Delimiter );
--    putline(w_log,' F_Transfer_Ftp           => ' ||bool_to_char(F_Transfer_Ftp ) );
--    --putline(w_log,' f_end_of_line            => ' ||f_end_of_line );
--    putline(w_log,' V_Sequence1              => ' ||V_Sequence1 );
--    putline(w_log,' V_Sequence2              => ' ||V_Sequence2 );
--    putline(w_log,' V_Sequence3              => ' ||V_Sequence3 );
--    putline(w_log,' V_Detail_Lines           => ' ||V_Detail_Lines );
    putline(w_log,' V_Trx_Lines              => ' ||V_Trx_Lines );
    putline(w_log,' V_Sum_Trans              => ' ||V_Sum_Trans );
--    putline(w_log,' V_Report_Lines           => ' ||V_Report_Lines );
    putline(w_log,' W_Log                    => ' ||W_Log );
    putline(w_log,' W_Output                 => ' ||W_Output );
    putline(w_log,' W_File                   => ' ||W_File );
    putline(w_log,' w_dbms                   => ' ||w_dbms );
    putline(w_log,' W_Wich                   => ' ||W_Wich );
    putline(w_log,' W_Init_File              => ' ||bool_to_char(W_Init_File ) );
    putline(w_log,' W_File_Name              => ' ||W_File_Name );
    putline(w_log,' W_File_Ext               => ' ||W_File_Ext );
    putline(w_log,' W_File_Dir               => ' ||W_File_Dir );
    putline(w_log,' W_File_FTP               => ' ||W_File_FTP );
    putline(w_log,' E_Start_Flag             => ' ||bool_to_char(E_Start_Flag ) );
    putline(w_log,' E_Proper_exe             => ' ||bool_to_char(E_Proper_exe) );
    putline(w_log,' E_Error_Desc             => ' ||E_Error_Desc );
    putline(w_log,' E_Error_Code             => ' ||E_Error_Code );


    
end;


procedure main (
             Errbuf     Out          Varchar2       --+ 1
            ,Retcode    Out          Varchar2       --+ 2
            ,pin_Bank_Acc            Number         --+ 3
            ,Pin_Pay_Document        Number         --+ 4
            ,Pin_Format_used         Number         --+ 5
            ,Pin_Doc_Ini             Number         --+ 6
            ,Pin_Doc_Fin             Number         --+ 7
            ,Pin_Start_Date          Varchar2       --+ 8
            ,Pin_End_Date            Varchar2       --+ 9
            ,Pin_Base_Amount         Number         --+ 10
            ,Pin_Top_Amount          Number         --+ 11
            ,pin_process_type        varchar2       --+ 12
            ,Pin_Transfer_Ftp        Varchar2       --+ 13
            ,Pin_Directory           Varchar2       --+ 14
            ,Pin_Only_Unsent         Varchar2       --+ 15
            ,Pin_debug_flag Varchar2 default '1'    --+ 16
            ) IS
    
    Field                   Varchar2(4000);
    Line                    Clob;
    
    BEGIN


        fnd_file.put_line(fnd_file.log,'---------------------------------------------------');
        fnd_file.put_line(fnd_file.log,',Errbuf             =>''' || to_char(Errbuf ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Retcode            =>''' || to_char(Retcode ) ||'''' );
        fnd_file.put_line(fnd_file.log,',pin_Bank_Acc       =>''' || to_char(pin_Bank_Acc ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Pay_Document   =>''' || to_char(Pin_Pay_Document ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Format_used    =>''' || to_char(Pin_Format_used ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Doc_Ini        =>''' || to_char(Pin_Doc_Ini ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Doc_Fin        =>''' || to_char(Pin_Doc_Fin ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Start_Date     =>''' || to_char(Pin_Start_Date ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_End_Date       =>''' || to_char(Pin_End_Date ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Base_Amount    =>''' || to_char(Pin_Base_Amount ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Top_Amount     =>''' || to_char(Pin_Top_Amount ) ||'''' );
        fnd_file.put_line(fnd_file.log,',pin_process_type   =>''' || to_char(pin_process_type ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Transfer_Ftp   =>''' || to_char(Pin_Transfer_Ftp ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Directory      =>''' || to_char(Pin_Directory ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_Only_Unsent    =>''' || to_char(Pin_Only_Unsent ) ||'''' );
        fnd_file.put_line(fnd_file.log,',Pin_debug_flag     =>''' || to_char(Pin_debug_flag ) ||'''' );
        fnd_file.put_line(fnd_file.log,'---------------------------------------------------');

        --+ set Global Varibles for formating and Output
        --+ Checks if minimun requirements are place, also the correct configuration


        initialize (
                   P_Bank_Id            => null
                  ,P_Bank_Acc           => Pin_Bank_Acc
                  ,P_Pay_Document       => Pin_Pay_Document
                  ,P_Format_Used        => Pin_Format_used
                  ,P_Start_Date         => pin_Start_Date
                  ,P_End_Date           => pin_End_Date
                  ,P_Doc_Ini            => Pin_Doc_Ini
                  ,P_Doc_Fin            => Pin_Doc_Fin
                  ,P_Base_Amount        => Pin_Base_Amount
                  ,P_Top_Amount         => Pin_Top_Amount
                  ,P_TRANSFER_FTP       => Pin_Transfer_Ftp
                  ,p_directory          => Pin_Directory
                  ,P_Only_Unsent        => Pin_Only_Unsent
                  ,p_debug_flag         => Pin_debug_flag
                   );
                   
        putline(w_log,'');
        putline(w_log,'Start process log');
        putline(w_log,'+---------------------------------------------------------------------------+');



        IF E_Start_Flag THEN

            IF f_TRX_HEADER THEN
--                putline(w_WICH,'************************* Begin Process for HEADER ************************* ');
                
                FOR L IN C_FILE(k_Header) LOOP

                    FIELD := GENERATE_VALUE (
                             L.SECUENCE,
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

                --PUTLINE(w_wich, SUBSTR( LINE, 1, 1024 )   );
                put(w_wich, LINE);

            END IF;
          
            IF f_TRX_BODY THEN                
                v_SEQUENCE1 := 1;

                for i in c_checks loop
                    CHECKS_LINE( CHECK_ID  => i.CHECK_ID );
                end loop;

            END IF;
           
            IF f_TRX_FOOTER THEN
--                putline(w_log,'************************* Begin Process for TRAILER  ************************* ');
                
                FOR L IN C_FILE(k_TRAILER) LOOP

                    FIELD := GENERATE_VALUE (
                         L.SECUENCE ,
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

                --PUTLINE(w_wich,LINE);
                put(w_wich, LINE);

            END IF;
               
        END IF;

       
        IF e_START_FLAG  THEN

            
            if f_transfer_ftp then
                null;
--                UPDATE_PROCESS_CHECKS;
            end if;
           null;
            
            if W_Init_File then
                close_file;
            end if;
           
--           if Pin_debug_flag = '1' then
--                putline(w_log,'Sub request Will Be Raised at this point');
--                --REPORT_DETAILS (w_report);
--                report_subrequest; --+ This Raise a Report of The payments Just Send
--           end if; 

        end if;
        

        
        putline(w_log,'+---------------------------------------------------------------------------+');
        putline(w_log,'End process log');
        commit;
    EXCEPTION
        WHEN OTHERS THEN
            putline(w_log,'Main Error Message Is: '||SQLERRM);
      retcode   := '2';
      errbuf    := SQLERRM;
     ROLLBACK;

    END;
    
    
procedure REPORT (
             Errbuf     Out          Varchar2       --+ 1
            ,Retcode    Out          Varchar2       --+ 2
            ,pin_Bank_Acc            Number         --+ 3
            ,Pin_Pay_Document        Number         --+ 4
            ,Pin_Doc_Ini             Number         --+ 6
            ,Pin_Doc_Fin             Number         --+ 7
            ,Pin_Start_Date          Varchar2       --+ 8
            ,Pin_End_Date            Varchar2       --+ 9
            ,Pin_Base_Amount         Number         --+ 10
            ,Pin_Top_Amount          Number         --+ 11
            ,Pin_Only_Unsent         Varchar2       --+ 14
            ,Pin_debug_flag Varchar2 default '1'    --+ 15
            ) IS
    
    BEGIN
        
        initialize (
                   P_Bank_Id            => null
                  ,P_Bank_Acc           => pin_Bank_Acc
                  ,P_Pay_Document       => Pin_Pay_Document
                  ,P_Format_Used        => null
                  ,P_Start_Date         => Pin_Start_Date
                  ,P_End_Date           => Pin_End_Date
                  ,P_Doc_Ini            => Pin_Doc_Ini
                  ,P_Doc_Fin            => Pin_Doc_Fin
                  ,P_Base_Amount        => Pin_Base_Amount
                  ,P_Top_Amount         => Pin_Top_Amount
                  ,P_TRANSFER_FTP       => null
                  ,p_directory          => null
                  ,P_Only_Unsent        => Pin_Only_Unsent
                  ,p_debug_flag         => Pin_debug_flag
                   );

       REPORT_DETAILS (W_Output);

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

    ROWS_UPDATED        NUMBER;   
    aux_rows            number;
    USER_GRANTED_ID     NUMBER;    
    
BEGIN



        
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
        
        REPORT_DETAILS(w_report);
        
    end;

END;

END;
/
