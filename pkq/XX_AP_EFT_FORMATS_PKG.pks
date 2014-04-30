CREATE OR REPLACE PACKAGE BOLINF.XX_AP_EFT_FORMATS_PKG AUTHID CURRENT_USER AS

TYPE curtype IS REF CURSOR;

unbound_variable exception;
    PRAGMA EXCEPTION_INIT(unbound_variable, -01006);


/******************************************************************
    Varibles globales de las cueles se genera el archivo bancario
******************************************************************/

    G_Bank_Id           Number := 0;
    G_Bank_Acc          Number := 0;
    G_Pay_Document      Number := 0;
    G_Format_Used       Number := 0;
    G_Start_Date        Date;
    G_End_Date          Date;
    G_Base_Amount       Number := 0;
    G_Top_Amount        Number := 0;
    G_Doc_Ini           Number := 0;
    G_Doc_Fin           Number := 0;
    G_Checkrun_Id       Number := 0;
    G_All_Checks        Varchar2(10)    := '';
    G_Status_Check      Varchar2(10)    := 'NEW';
    G_debug_flag        boolean         := false;


/******************************************************************
    Constans to avoid 
******************************************************************/
    
    k_Header            constant    Varchar2(25) := 'HEADER';
    k_Body              constant    Varchar2(25) := 'BODY';
    k_Detail            constant    Varchar2(25) := 'DETAIL';
    k_TRAILER           constant    Varchar2(25) := 'TRAILER';
    
    k_delimited         constant    Varchar2(25) := 'DELIMITED';
    k_fixed             constant    Varchar2(25) := 'FIXED_WIDTH';
    
    k_NEW               constant    Varchar2(25) := 'NEW';
    K_PRINTED           constant    Varchar2(25) := 'PRINTED';
    
    k_CONSTANT          constant    Varchar2(25) := 'CONSTANT';
    k_DINAMIC           constant    Varchar2(25) := 'DINAMIC';
    k_SEQUENCE1         constant    Varchar2(25) := 'SEQUENCE1';
    k_SEQUENCE2         constant    Varchar2(25) := 'SEQUENCE2';
    k_SEQUENCE3         constant    Varchar2(25) := 'SEQUENCE3';
    k_TRX_LINES         constant    Varchar2(25) := 'TRX_LINES';
    k_SUM_TRANS         constant    Varchar2(25) := 'SUM_TRANS';
    
    F_Trx_Header        Boolean := False;
    F_Trx_Body          Boolean := False;
    F_Trx_Detail        Boolean := False;
    F_Trx_Footer        Boolean := False;
    F_FORMAT_TYPE       Varchar2(100)   := k_delimited;
    F_Delimiter         Varchar2(1)     := chr(124);
    F_Transfer_Ftp      Boolean := False;
           
    V_Sequence1         Number := 0;    --+ CURRENT NUMBER RECORD IN TRX
    V_Sequence2         Number := 0;    --+ CURRENT NUMBER RECORD IN DETAIL
    V_Sequence3         Number := 0;    --+ CURRENT LINE IN ARCHIVE TRX AND DETAIL
    V_Detail_Lines      Number := 0;    --+ SUM OF ALL DETAIL LINES IN A TRX
    V_Trx_Lines         Number := 0;    --+ COUNT OF ALL TRX IN ARCHIVE
    V_Sum_Trans         Number := 0;    --+ SUM OF TRX AMOUNTS
    V_Report_Lines      Number := 0;    --+ COUNT OF ALL LINES IN REPORT TRX+DETAIL

    W_Log               Number              := Fnd_File.Log;
    W_Output            Number              := Fnd_File.Output;
    W_File              Constant Number     := 3;
    w_dbms              constant number     := 4;
    W_Wich              Number              := W_Output;
    W_Init_File         Boolean             := False;
        
    W_File_Name         Varchar2(150)       := 'entrust_ctorres';
    W_File_Ext          Varchar2(10)        := '';
    W_File_Dir          Varchar2(50)        := 'XXSV_FILE_ELECTRONIC_DIR';
    W_File_Out          Utl_File.File_Type;
    w_count             number              := 0;
    
    E_Start_Flag        Boolean             := False;   --+ Whether to start
    E_Proper_exe        boolean             := true;    --+ True if all went ok
    
    E_Error_Desc        Varchar2(1000)      := '';      --+ concurrent out var       
    E_Error_Code        VARCHAR2(1)         := '0';     --+ Concurrent out var
    
    Type T_CHECKS       Is Record
       (Check_Id            Number
       ,Doc_Sequence_Value  Number
       ,Check_Number        Number
       ,Amount              Number
       ,Check_Date          Date
       ,Vendor_Name         Varchar2(240)
       ,Send_Status         Varchar2(50)
       ,Vendor_Site_Code    Varchar2(50)
       );

    Cursor C_Checks     Return T_Checks;
       
    type T_file is record
       (FORMAT_TYPE         XX_AP_EFT_FORMATS.FORMAT_TYPE%TYPE                  --+ 1
       ,DELIMITER           VARCHAR2(1)                                         --+ 2
       ,TYPE_VALUE          XX_AP_EFT_FORMAT_DEFINITIONS.TYPE_VALUE%TYPE        --+ 3
       ,CONSTANT_VALUE      XX_AP_EFT_FORMAT_DEFINITIONS.CONSTANT_VALUE%TYPE    --+ 4
       ,SECUENCE            XX_AP_EFT_FORMAT_DEFINITIONS.SECUENCE%TYPE          --+ 5
       ,START_POSITION      XX_AP_EFT_FORMAT_DEFINITIONS.START_POSITION%TYPE    --+ 6
       ,END_POSITION        XX_AP_EFT_FORMAT_DEFINITIONS.END_POSITION%TYPE      --+ 7
       ,DATA_TYPE           XX_AP_EFT_FORMAT_DEFINITIONS.DATA_TYPE%TYPE         --+ 8
       ,FORMAT_MODEL        XX_AP_EFT_FORMAT_DEFINITIONS.FORMAT_MODEL%TYPE      --+ 9
       ,PADDING_CHARACTER   varchar2(1)                                         --+ 10
       ,DIRECTION_PADDING   XX_AP_EFT_FORMAT_DEFINITIONS.DIRECTION_PADDING%TYPE --+ 11
       ,NEEDS_PADDING       VARCHAR2(1)                                         --+ 12
       ,SQL_STATEMENT       XX_AP_EFT_FORMAT_DEFINITIONS.SQL_STATEMENT%TYPE     --+ 13
       );
    
    CURSOR C_FILE ( P_PART VARCHAR2 )  RETURN T_file;

Procedure MAIN (
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
            ,Pin_Only_Unsent         Varchar2       --+ 14
            ,Pin_debug_flag Varchar2 default '1'    --+ 15
            );

Procedure REPORT (
    Errbuf     Out      Varchar2,
    Retcode    Out      Varchar2,
    Bank_Id             Number,
    Bank_Acc            Number,
    Pay_Document        Number,
    Start_Date          Varchar2,
    End_Date            Varchar2,
    Checkrun_Id         Number,
    P_Doc_Ini           Number,
    P_Doc_Fin           Number,
    Base_Amount         Number,
    Top_Amount          Number);

Procedure XX_UPDATE_CHECKS_STATUS (
    Errbuf     Out      Varchar2,
    Retcode    Out      Varchar2,
    Pay_Document        Number,
    P_Start_Date        Varchar2,
    P_End_Date          Varchar2,
    P_Doc_Ini           Number,
    P_Doc_Fin           Number,
    Base_Amount         Number,
    Top_Amount          Number,
    Set_Status          Varchar2);

          
Procedure Putline(Which In Number, Buff In Varchar2);   
       
End;
/
