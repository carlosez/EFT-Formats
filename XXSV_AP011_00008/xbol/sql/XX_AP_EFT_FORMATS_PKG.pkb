CREATE OR REPLACE PACKAGE BODY BOLINF.XX_AP_EFT_FORMATS_PKG
IS

CURSOR c_checks return t_checks IS
SELECT CH.CHECK_ID
      ,CH.DOC_SEQUENCE_VALUE
      ,ch.check_number
      ,CH.AMOUNT
      ,CH.CHECK_DATE
      ,CH.VENDOR_NAME
      ,status.FLEX_VALUE_MEANING/* g_process_type ||'|' ||CH.ATTRIBUTE14  ||'|'  ||status.FLEX_VALUE_MEANING */SEND_STATUS
      ,SS.VENDOR_SITE_CODE
  FROM APPS.AP_CHECKS_ALL CH
      ,APPS.AP_SUPPLIER_SITES_ALL SS
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
   and decode(g_process_type,'FINAL', K_PRINTED, NVL(CH.ATTRIBUTE14,k_NEW)) = status.FLEX_VALUE          --+ Presentation
   AND NVL(CH.ATTRIBUTE14,k_NEW) in ( k_new, g_STATUS_CHECK ) --+ Fillter
   AND CH.VOID_DATE IS NULL
   order by ch.check_number;


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
       ,chr( nvl( DT.PADDING_CHARACTER, 32  )) PADDING_CHARACTER    --+ 10
       ,decode(FORMAT_TYPE , 'DELIMITED', DT.DIRECTION_PADDING , 'FIXED_WIDTH'
       ,decode( nvl(DT.DIRECTION_PADDING,'NONE')
       ,'NONE','RIGTH',DT.DIRECTION_PADDING )  ) DIRECTION_PADDING  --+ 11
       ,decode(FORMAT_TYPE , 'FIXED_WIDTH','Y'
       , decode(DT.DIRECTION_PADDING,'NONE','N'
            ,'RIGTH','Y', 'LEFT', 'Y') )NEEDS_PADDING               --+ 12
       ,DT.SQL_STATEMENT                                            --+ 13
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
    putline(w_log,'+---------------------------------------------------------------------------+');
    putline(w_log,' Opening File ');
    putline(w_log,' w_file_dir       '||w_file_dir);
    putline(w_log,' w_file_name      '||w_file_name);
    putline(w_log,' w_file_ext       '||w_file_ext);
    putline(w_log,' w_init_file      '||bool_to_char(w_init_file));
    IF NOT w_init_file THEN

        w_file_out := UTL_FILE.FOPEN (w_file_dir, w_file_name || w_file_ext, 'w',32767);
        w_init_file := true;
        DBMS_OUTPUT.PUT_LINE('# Opening File #');
        putline(w_log,' w_init_file change to  '||bool_to_char(w_init_file));

    END IF;
    putline(w_log,'+---------------------------------------------------------------------------+');
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
        else
            fnd_file.put_line( FND_FILE.LOG, 'File is Close : '||BUFF);
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
        else
             fnd_file.put_line( FND_FILE.LOG, 'File is Close : '||BUFF);
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

begin


    g_report_sub_request  := APPS.FND_REQUEST .SUBMIT_REQUEST
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
                   ,g_Top_Amount
                   ,G_Unsent_Only
                   ,G_process_type
                   ,chr(0)
                  );

        
                  --+ 65269, 2552, , , 2013/12/20 00:00:00, 2013/12/30 00:00:00, 0, 99999999.99, Y
    
    putline(w_log,'+---------------------------------------------------------------------------+');
    putline(w_log,'+_subrequest submitted. ID = ' || g_report_sub_request);
    putline(w_log,'+---------------------------------------------------------------------------+');
    commit ;
exception
when others then
    putline(w_log,'Exception ' || sqlerrm);
end;


/*****************************************************************
                   Move Phisical File
******************************************************************/

procedure move_file is
v_request_id NUMBER;
begin
       v_request_id :=
      APPS.FND_REQUEST.
      SUBMIT_REQUEST ('XBOL',
                      'XX_EFT_MOVE_FILE',
                      '',
                      '',
                      FALSE,
                      W_File_default,
                      W_File_FTP,
                      W_File_Name || W_File_Ext,
                      CHR (0));
    putline(w_log,'+---------------------------------------------------------------------------+');
    putline(w_log,' Moving File Request = ' || v_request_id);
    putline(w_log,'+---------------------------------------------------------------------------+');

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


procedure update_status is
    CURSOR C_Checks_U IS
SELECT ch.ROWID, CH.*
  FROM APPS.AP_CHECKS_ALL CH
      ,APPS.AP_SUPPLIER_SITES_ALL SS
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
   and NVL(CH.ATTRIBUTE14,k_NEW) = status.FLEX_VALUE
   AND NVL(CH.ATTRIBUTE14,k_NEW) in ( k_new, g_STATUS_CHECK )
   AND CH.VOID_DATE IS NULL;

    ROWS_UPDATED        NUMBER;
    aux_rows            number;


begin

    begin
         putline(w_log,'+---------------------------------------------------------------------------+');
         putline(w_log,' Updating Payment Status');
        for REC_I in c_checks_u loop

            AP_AC_TABLE_HANDLER_PKG.UPDATE_ROW (
             p_Rowid                              =>     REC_I.Rowid
            ,p_Amount                             =>     REC_I.Amount
            ,p_Ce_Bank_Acct_Use_Id                =>     REC_I.Ce_Bank_Acct_Use_Id
            ,p_Bank_Account_Name                  =>     REC_I.Bank_Account_Name
            ,p_Check_Date                         =>     REC_I.Check_Date
            ,p_Check_Id                           =>     REC_I.Check_Id
            ,p_Check_Number                       =>     REC_I.Check_Number
            ,p_Currency_Code                      =>     REC_I.Currency_Code
            ,p_Last_Updated_By                    =>     REC_I.Last_Updated_By
            ,p_Last_Update_Date                   =>     REC_I.Last_Update_Date
            ,p_Payment_Type_Flag                  =>     REC_I.Payment_Type_Flag
            ,p_Address_Line1                      =>     REC_I.Address_Line1
            ,p_Address_Line2                      =>     REC_I.Address_Line2
            ,p_Address_Line3                      =>     REC_I.Address_Line3
            ,p_Checkrun_Name                      =>     REC_I.Checkrun_Name
            ,p_Check_Format_Id                    =>     REC_I.Check_Format_Id
            ,p_Check_Stock_Id                     =>     REC_I.Check_Stock_Id
            ,p_City                               =>     REC_I.City
            ,p_Country                            =>     REC_I.Country
            ,p_Last_Update_Login                  =>     REC_I.Last_Update_Login
            ,p_Status_Lookup_Code                 =>     REC_I.Status_Lookup_Code
            ,p_Vendor_Name                        =>     REC_I.Vendor_Name
            ,p_Vendor_Site_Code                   =>     REC_I.Vendor_Site_Code
            ,p_External_Bank_Account_Id           =>     REC_I.External_Bank_Account_Id
            ,p_Zip                                =>     REC_I.Zip
            ,p_Bank_Account_Num                   =>     REC_I.Bank_Account_Num
            ,p_Bank_Account_Type                  =>     REC_I.Bank_Account_Type
            ,p_Bank_Num                           =>     REC_I.Bank_Num
            ,p_Check_Voucher_Num                  =>     REC_I.Check_Voucher_Num
            ,p_Cleared_Amount                     =>     REC_I.Cleared_Amount
            ,p_Cleared_Date                       =>     REC_I.Cleared_Date
            ,p_Doc_Category_Code                  =>     REC_I.Doc_Category_Code
            ,p_Doc_Sequence_Id                    =>     REC_I.Doc_Sequence_Id
            ,p_Doc_Sequence_Value                 =>     REC_I.Doc_Sequence_Value
            ,p_Province                           =>     REC_I.Province
            ,p_Released_Date                      =>     REC_I.Released_Date
            ,p_Released_By                        =>     REC_I.Released_By
            ,p_State                              =>     REC_I.State
            ,p_Stopped_Date                       =>     REC_I.Stopped_Date
            ,p_Stopped_By                         =>     REC_I.Stopped_By
            ,p_Void_Date                          =>     REC_I.Void_Date
            ,p_Attribute1                         =>     REC_I.Attribute1
            ,p_Attribute10                        =>     REC_I.Attribute10
            ,p_Attribute11                        =>     REC_I.Attribute11
            ,p_Attribute12                        =>     REC_I.Attribute12
            ,p_Attribute13                        =>     REC_I.Attribute13
            ,p_Attribute14                        =>     G_Set_status
            ,p_Attribute15                        =>     REC_I.Attribute15
            ,p_Attribute2                         =>     REC_I.Attribute2
            ,p_Attribute3                         =>     REC_I.Attribute3
            ,p_Attribute4                         =>     REC_I.Attribute4
            ,p_Attribute5                         =>     REC_I.Attribute5
            ,p_Attribute6                         =>     REC_I.Attribute6
            ,p_Attribute7                         =>     REC_I.Attribute7
            ,p_Attribute8                         =>     REC_I.Attribute8
            ,p_Attribute9                         =>     REC_I.Attribute9
            ,p_Attribute_Category                 =>     'EL SALVADOR' -- REC_I.Attribute_Category
            ,p_Future_Pay_Due_Date                =>     REC_I.Future_Pay_Due_Date
            ,p_Treasury_Pay_Date                  =>     REC_I.Treasury_Pay_Date
            ,p_Treasury_Pay_Number                =>     REC_I.Treasury_Pay_Number
            ,p_Withholding_Status_Lkup_Code       =>     REC_I.Withholding_Status_Lookup_Code
            ,p_Reconciliation_Batch_Id            =>     REC_I.Reconciliation_Batch_Id
            ,p_Cleared_Base_Amount                =>     REC_I.Cleared_Base_Amount
            ,p_Cleared_Exchange_Rate              =>     REC_I.Cleared_Exchange_Rate
            ,p_Cleared_Exchange_Date              =>     REC_I.Cleared_Exchange_Date
            ,p_Cleared_Exchange_Rate_Type         =>     REC_I.Cleared_Exchange_Rate_Type
            ,p_Address_Line4                      =>     REC_I.Address_Line4
            ,p_County                             =>     REC_I.County
            ,p_Address_Style                      =>     REC_I.Address_Style
            ,p_Org_Id                             =>     REC_I.Org_Id
            ,p_Vendor_Id                          =>     REC_I.Vendor_Id
            ,p_Vendor_Site_Id                     =>     REC_I.Vendor_Site_Id
            ,p_Exchange_Rate                      =>     REC_I.Exchange_Rate
            ,p_Exchange_Date                      =>     REC_I.Exchange_Date
            ,p_Exchange_Rate_Type                 =>     REC_I.Exchange_Rate_Type
            ,p_Base_Amount                        =>     REC_I.Base_Amount
            ,p_Checkrun_Id                        =>     REC_I.Checkrun_Id
            ,p_global_attribute_category          =>     REC_I.global_attribute_category
            ,p_global_attribute1                  =>     REC_I.global_attribute1
            ,p_global_attribute2                  =>     REC_I.global_attribute2
            ,p_global_attribute3                  =>     REC_I.global_attribute3
            ,p_global_attribute4                  =>     REC_I.global_attribute4
            ,p_global_attribute5                  =>     REC_I.global_attribute5
            ,p_global_attribute6                  =>     REC_I.global_attribute6
            ,p_global_attribute7                  =>     REC_I.global_attribute7
            ,p_global_attribute8                  =>     REC_I.global_attribute8
            ,p_global_attribute9                  =>     REC_I.global_attribute9
            ,p_global_attribute10                 =>     REC_I.global_attribute10
            ,p_global_attribute11                 =>     REC_I.global_attribute11
            ,p_global_attribute12                 =>     REC_I.global_attribute12
            ,p_global_attribute13                 =>     REC_I.global_attribute13
            ,p_global_attribute14                 =>     REC_I.global_attribute14
            ,p_global_attribute15                 =>     REC_I.global_attribute15
            ,p_global_attribute16                 =>     REC_I.global_attribute16
            ,p_global_attribute17                 =>     REC_I.global_attribute17
            ,p_global_attribute18                 =>     REC_I.global_attribute18
            ,p_global_attribute19                 =>     REC_I.global_attribute19
            ,p_global_attribute20                 =>     REC_I.global_attribute20
            ,p_transfer_priority                  =>     REC_I.transfer_priority
            ,p_maturity_exchange_rate_type        =>     REC_I.maturity_exchange_rate_type
            ,p_maturity_exchange_date             =>     REC_I.maturity_exchange_date
            ,p_maturity_exchange_rate             =>     REC_I.maturity_exchange_rate
            ,p_description                        =>     REC_I.description
            ,p_anticipated_value_date             =>     REC_I.anticipated_value_date
            ,p_actual_value_date                  =>     REC_I.actual_value_date
            ,p_PAYMENT_METHOD_CODE                =>     REC_I.PAYMENT_METHOD_CODE
            ,p_PAYMENT_PROFILE_ID                 =>     REC_I.PAYMENT_PROFILE_ID
            ,p_BANK_CHARGE_BEARER                 =>     REC_I.BANK_CHARGE_BEARER
            ,p_SETTLEMENT_PRIORITY                =>     REC_I.SETTLEMENT_PRIORITY
            ,p_payment_document_id                =>     REC_I.payment_document_id
            ,p_party_id                           =>     REC_I.party_id
            ,p_party_site_id                      =>     REC_I.party_site_id
            ,p_legal_entity_id                    =>     REC_I.legal_entity_id
            ,p_payment_id                         =>     REC_I.payment_id
            ,p_calling_sequence                   =>     2
            ,p_Remit_To_Supplier_Name             =>     REC_I.Remit_To_Supplier_Name
            ,p_Remit_To_Supplier_Id               =>     REC_I.Remit_To_Supplier_Id
            ,p_Remit_To_Supplier_Site             =>     REC_I.Remit_To_Supplier_Site
            ,p_Remit_To_Supplier_Site_Id          =>     REC_I.Remit_To_Supplier_Site_Id
            ,p_Relationship_Id                    =>     REC_I.Relationship_Id
            );

            PutLine(w_log,' Updating Check  : ' || to_char( REC_I.Check_Id) || ' Set Status      : ' || G_Set_status );

        end loop;
            commit;
            putline(w_log,'+---------------------------------------------------------------------------+');
    exception
        when others then

            PutLine(w_log,'Error Updating Payments ' || sqlerrm  );
        rollback;
    end;
end;

procedure  REPORT_DETAILS ( p_wich number)  IS

V_LEGAL_ENTITY    VARCHAR2(400);
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
    TL_LEGAL_ENTITY              Varchar2(250);


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
    and LANGUAGE = 'US' --+userenv('lang')
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
            when 'LEGAL_ENTITY'     then TL_LEGAL_ENTITY        :=   x.FLEX_VALUE_MEANING;
            else null;
            end case;
        end loop;


        begin
        select  b.BANK_NAME  , ba.BANK_ACCOUNT_NAME, dc.PAYMENT_DOCUMENT_NAME, initcap( LEOU.LEGAL_ENTITY_NAME) LEGAL_ENTITY
              into V_BANK_NAME , V_BANK_ACC_NAME, V_PAYMENT_DOC, V_LEGAL_ENTITY
        from  apps.ce_banks_v b
             ,apps.ce_bank_acct_uses_all bu
             ,ce_bank_accounts ba
             ,apps.ce_payment_documents dc
             ,apps.XLE_LE_OU_LEDGER_V leou
         where bu.BANK_ACCOUNT_ID = ba.BANK_ACCOUNT_ID
           and ba.BANK_ID  = b.BANK_PARTY_ID
           and dc.INTERNAL_BANK_ACCOUNT_ID = bu.BANK_ACCOUNT_ID
           and LEOU.OPERATING_UNIT_ID = bu.org_id
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
    PUTLINE(p_wich,RPAD(TL_LEGAL_ENTITY,18,' ') ||': '||V_LEGAL_ENTITY );
    PUTLINE(p_wich,RPAD(TL_BANK,18,' ') ||': '||V_BANK_NAME );
    PUTLINE(p_wich,RPAD(TL_BANK_ACCOUNT,18,' ') ||': '||V_BANK_ACC_NAME  );
    PUTLINE(p_wich,RPAD(TL_PAYMENT_DOCUMENT,18,' ') ||': '||V_PAYMENT_DOC);
    PUTLINE(p_wich,RPAD(TL_DATE_TIME,18,' ') ||': '||fnd_date.date_to_displayDT(sysdate) );

     PUTLINE(p_wich,'');

    LINE:='';
    LINE := LINE ||'  ' || LPAD(TL_CHECK_NUMBER ,15, ' ');
    LINE := LINE ||'  ' || RPAD(TL_CHECK_DATE   ,14, ' ');
    LINE := LINE ||'  ' || RPAD(TL_SUPPLIER_NAME,50, ' ');
    LINE := LINE ||'  ' || RPAD(TL_SUPPLIER_SITE,15, ' ');
    LINE := LINE ||'  ' || LPAD(TL_CHECK_AMOUNT ,15, ' ');
    LINE := LINE ||'  ' || RPAD(TL_SEND_STATUS  ,15, ' ');

    PUTLINE(p_wich,LINE);

        FOR C IN c_checks  LOOP
            LINE:='';
            LINE := LINE ||'  ' || LPAD(TO_CHAR(NVL(C.CHECK_NUMBER,0))             ,15,' ');
            LINE := LINE ||'  ' || RPAD(fnd_date.date_to_displaydate(C.CHECK_DATE) ,14,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_NAME,' ')                     ,50,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.VENDOR_SITE_CODE,' ')                ,15,' ');
            LINE := LINE ||'  ' || LPAD(TO_CHAR(C.AMOUNT,'999,999,999.99')         ,15,' ');
            LINE := LINE ||'  ' || RPAD(NVL(C.SEND_STATUS,' ')                    ,15,' '); --+ 15
            PUTLINE(p_wich,LINE);
        END LOOP;

    PUTLINE(p_wich,lpad('-',135,'-'));
    PUTLINE(p_wich,'  Total '||LPAD( TO_CHAR(v_TRX_LINES),9,' ') || rpad(' ',87,' ')  ||  LPAD(TO_CHAR(v_SUM_TRANS,'999,999,999.99'),15,' ')  );

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
           P_Bank_Id            Number      default null
          ,P_Bank_Acc           Number      default null    --+ 2
          ,P_Pay_Document       Number      default null    --+ 3
          ,P_Format_Used        Number      default null    --+ 4
          ,P_Start_Date         Varchar2    default null    --+ 5
          ,P_End_Date           Varchar2    default null    --+ 6
          ,P_Doc_Ini            Number      default null    --+ 7
          ,P_Doc_Fin            Number      default null    --+ 8
          ,P_Base_Amount        Number      default null    --+ 9
          ,P_Top_Amount         Number      default null    --+ 10
          ,p_process_type       Varchar2    default null    --+ 11
          ,P_Transfer_Ftp       Varchar2    default null    --+ 12
          ,P_Directory          Varchar2    default null    --+ 13
          ,P_Only_Unsent        Varchar2    default null    --+ 14
          ,P_Debug_Flag         Varchar2    default null    --+ 15
          ,P_Set_Status         Varchar2    default null    --+ 16
          ,p_call_from          Varchar2    default null    --+ 17
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

    FND_PROFILE.GET ('USER_ID', g_USER_ID);
    FND_PROFILE.GET ('RESP_ID', g_RESP_ID);
    FND_PROFILE.GET ('RESP_APPL_ID', g_RESP_APPL_ID);
    FND_GLOBAL.APPS_INITIALIZE (g_USER_ID, g_RESP_ID, g_RESP_APPL_ID);

    if P_Debug_Flag != '1' then
        g_Debug_Flag := true;
        W_Log := w_dbms;
        w_WICH := W_File;
        putline(W_Log,' Debug Is Set To 1 ' );
    else
        putline(W_Log,' Debug Is Set To ' || P_Debug_Flag );
        w_WICH := W_File;
    end if;

    if p_call_from in ('UNLOCK') then
        G_Set_status    := P_Set_Status;
    end if;

    if  p_call_from in ('MAIN', 'UNLOCK', 'REPORT') then
        
        
        if  P_Only_Unsent = 'Y' then
            G_STATUS_CHECK  := k_NEW;
            G_unsent_only   := 'Y';
        elsif   P_Only_Unsent = 'N' then
            G_STATUS_CHECK  := K_PRINTED;
            G_unsent_only   := 'N';
        end if;
    end if;

    if p_call_from in ('MAIN') then

        begin
            select  b.BANK_PARTY_ID,bu.BANK_ACCOUNT_ID
               , REGEXP_REPLACE     ( ou.name
                            ||'_' || dc.PAYMENT_DOCUMENT_NAME
                            ||'_' || TO_CHAR(SYSDATE,'YYYY-MON-DD_HHAM-MI-SS')
                                    ,'[^A-Za-z0-9_-]', '')
              into g_bank_id , g_BANK_ACC, W_File_Name
        from  apps.ce_banks_v b
            ,apps.ce_bank_acct_uses_all bu
            ,ce_bank_accounts ba
            , apps.ce_payment_documents dc
            ,apps.hr_operating_units ou
         where bu.BANK_ACCOUNT_ID = ba.BANK_ACCOUNT_ID
           and ba.BANK_ID  = b.BANK_PARTY_ID
           and dc.INTERNAL_BANK_ACCOUNT_ID = bu.BANK_ACCOUNT_ID
           and ou.organization_id = bu.org_id
           and dc.PAYMENT_DOCUMENT_ID = G_Pay_Document
            ;
        exception
        when others then
            putline(w_log,'Error Retrieving Parameters ');
            putline(w_log,'SQLERRM: '||sqlerrm );
        end;
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
               select DIRECTORY_PATH into W_File_default
                from all_directories
                where DIRECTORY_NAME = w_file_dir
                ;
            exception when no_data_found then
                E_Error_Code := '1';
                PUTLINE(w_LOG,' Directory Does not exist in DB '||w_file_dir);
                when others then
                PUTLINE(w_LOG,' UnExpected Error all_directories '||SQLerrm);
            end;

            if W_File_default is not null  then
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

        G_process_type := p_process_type;
        
        if G_process_type  in ('FINAL')  then
            G_Set_status    := K_PRINTED;
            G_unsent_only   := 'Y';
        end if;

        if g_format_used is null then
            E_Error_Code := '1';
            putline(w_log,'Unexpected : This payment Document Does not have a format asosiated with.');
        end if;

    end if;

    if p_call_from in ('MAIN', 'REPORT') then

        GET_TRXAMOUNT_AND_TRXLINES;
        
        G_process_type := p_process_type;
        
        IF v_TRX_LINES = 0 THEN
            e_ERROR_CODE := '1';
            E_Error_Desc := 'Warning : Parameters did not retrieve any data';
            E_Start_Flag := false;
        END IF;


    end if;


    putline(w_log,' G_Bank_Id            => ' ||G_Bank_Id );
    putline(w_log,' G_Bank_Acc           => ' ||G_Bank_Acc );
    putline(w_log,' G_Pay_Document       => ' ||G_Pay_Document );
    putline(w_log,' G_Format_Used        => ' ||G_Format_Used );
    putline(w_log,' G_Start_Date         => ' ||G_Start_Date );
    putline(w_log,' G_End_Date           => ' ||G_End_Date );
    putline(w_log,' G_Base_Amount        => ' ||G_Base_Amount );
    putline(w_log,' G_Top_Amount         => ' ||G_Top_Amount );
    putline(w_log,' G_Doc_Ini            => ' ||G_Doc_Ini );
    putline(w_log,' G_Doc_Fin            => ' ||G_Doc_Fin );
    putline(w_log,' G_unsent_only        => ' ||G_unsent_only );
    putline(w_log,' G_Status_Check       => ' ||G_Status_Check );
    putline(w_log,' G_Set_status         => ' ||G_Set_status );
    putline(w_log,' G_debug_flag         => ' ||bool_to_char(G_debug_flag));
    putline(w_log,' W_Init_File          => ' ||bool_to_char(W_Init_File ) );
    putline(w_log,' E_Start_Flag         => ' ||bool_to_char(E_Start_Flag ) );
    putline(w_log,' E_Proper_exe         => ' ||bool_to_char(E_Proper_exe) );

end;


procedure MAIN (
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
    VPHASE_CODE Varchar2(50); VSTATUS_CODE Varchar2(50);

    BEGIN


        initialize(P_Bank_Acc           => Pin_Bank_Acc
                  ,P_Pay_Document       => Pin_Pay_Document
                  ,P_Format_Used        => Pin_Format_used
                  ,P_Start_Date         => pin_Start_Date
                  ,P_End_Date           => pin_End_Date
                  ,P_Doc_Ini            => Pin_Doc_Ini
                  ,P_Doc_Fin            => Pin_Doc_Fin
                  ,P_Base_Amount        => Pin_Base_Amount
                  ,P_Top_Amount         => Pin_Top_Amount
                  ,p_process_type       => pin_process_type
                  ,P_TRANSFER_FTP       => Pin_Transfer_Ftp
                  ,p_directory          => Pin_Directory
                  ,P_Only_Unsent        => Pin_Only_Unsent
                  ,p_debug_flag         => Pin_debug_flag
                  ,p_call_from          => 'MAIN'
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
                if G_process_type = 'FINAL' then
                    move_file; --+ Copy from default Directory to Specified
                end if;
            end if;
           null;

            if W_Init_File then
                close_file;
            end if;

            if E_Proper_exe then

                report_subrequest; --+ This Raise a Report of The payments
                COMMIT;
                    --+ LOOP PARA ESPERAR QUE FINALICE EL REQUEST
                LOOP
                    DBMS_LOCK.sleep(1);
                    SELECT PHASE_CODE,  STATUS_CODE
                      INTO VPHASE_CODE, VSTATUS_CODE
                      FROM FND_CONCURRENT_REQUESTS
                     WHERE REQUEST_ID = g_report_sub_request;
                EXIT WHEN VPHASE_CODE = 'C';
                END LOOP;

                if pin_process_type  in ('FINAL')  then
                    update_status;
                end if;
            end if;
        end if;

        putline(w_log,'+---------------------------------------------------------------------------+');
        putline(w_log,'End process log');

        errbuf  := E_Error_Desc;
        retcode := E_Error_Code;

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
            ,pin_process_type        varchar2   default 'DRAFT'     --+ 15
            ,Pin_debug_flag          Varchar2   default '1'    --+ 16
            ) IS

    BEGIN

        putline(w_log,'+---------------------------------------------------------------------------+');
        putline(w_log,'Proces type REPORT call '||pin_process_type);
        putline(w_log,'+---------------------------------------------------------------------------+');
        initialize(P_Bank_Acc           => pin_Bank_Acc
                  ,P_Pay_Document       => Pin_Pay_Document
                  ,P_Start_Date         => Pin_Start_Date
                  ,P_End_Date           => Pin_End_Date
                  ,P_Doc_Ini            => Pin_Doc_Ini
                  ,P_Doc_Fin            => Pin_Doc_Fin
                  ,P_Base_Amount        => Pin_Base_Amount
                  ,P_Top_Amount         => Pin_Top_Amount
                  ,P_Only_Unsent        => Pin_Only_Unsent
                  ,p_debug_flag         => Pin_debug_flag
                  ,p_process_type       => pin_process_type
                  ,p_call_from          => 'REPORT'
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






PROCEDURE UNLOCK (
             Errbuf     Out          Varchar2       --+ 1
            ,Retcode    Out          Varchar2       --+ 2
            ,pin_Bank_Acc            Number         --+ 3
            ,Pin_Pay_Document        Number         --+ 4
            ,Pin_Doc_Ini             Number         --+ 5
            ,Pin_Doc_Fin             Number         --+ 6
            ,Pin_Start_Date          Varchar2       --+ 7
            ,Pin_End_Date            Varchar2       --+ 8
            ,Pin_Base_Amount         Number         --+ 9
            ,Pin_Top_Amount          Number         --+ 10
            ,Pin_Set_Status          Varchar2       --+ 11
            ,Pin_User_granted        Varchar2       --+ 12
            ) IS

    USER_GRANTED_ID number;
BEGIN

        initialize (
           P_Bank_Acc           => pin_Bank_Acc
          ,P_Pay_Document       => Pin_Pay_Document
          ,P_Start_Date         => Pin_Start_Date
          ,P_End_Date           => Pin_End_Date
          ,P_Doc_Ini            => Pin_Doc_Ini
          ,P_Doc_Fin            => Pin_Doc_Fin
          ,P_Base_Amount        => Pin_Base_Amount
          ,P_Top_Amount         => Pin_Top_Amount
          ,p_call_from          => 'UNLOCK'
          ,P_Only_Unsent        => 'N'
          ,P_Set_Status         => Pin_Set_Status
           );

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
        and usr.USER_ID = Pin_User_granted
        AND upper(trim(FVT1.FLEX_VALUE_MEANING)) = usr.USER_NAME;


    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        ERRBUF  := 'User Does not have Access';
        fnd_file.PUT_LINE(fnd_file.OUTPUT,'User Does not have Access');
        RETCODE := 1;
        when too_many_rows then
        ERRBUF  := 'Contac Payables Setup Administator for Help';
        fnd_file.PUT_LINE(fnd_file.OUTPUT,'Contac Payables Setup Administator for Help');
        RETCODE := 1;
        when others then
        ERRBUF  := sqlerrm;
        fnd_file.PUT_LINE(fnd_file.OUTPUT,'Unexpected Error');
        RETCODE := 2;
    END;

    IF USER_GRANTED_ID IS NOT NULL THEN

        update_status;
        E_Error_Code  := '0';
        COMMIT;
        REPORT_DETAILS(w_report);
    ELSE
        --fnd_file.Put_Line(fnd_file.output,'User Does not have Access');
        E_Error_Code  := '1';
        E_Error_Desc  := 'User Does not have Access';
    end if;

    errbuf  := E_Error_Desc;
    retcode := E_Error_Code;
END;

END;
/
