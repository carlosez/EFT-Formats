declare
v_Errbuf varchar2(400);
v_retcode varchar2(30);
begin
XX_AP_EFT_FORMATS_PKG.MAIN(
         Errbuf             => v_Errbuf
        ,Retcode            => v_retcode
        ,pin_Bank_Acc       => null
        ,Pin_Pay_Document   => 416
        ,Pin_Format_used    => 15
        ,Pin_Doc_Ini        => null
        ,Pin_Doc_Fin        => null
        ,Pin_Start_Date     => '2013/12/01 00:00:00'
        ,Pin_End_Date       => '2013/12/10 00:00:00'
        ,Pin_Base_Amount    => 0
        ,Pin_Top_Amount     => 99999999
        ,Pin_Transfer_Ftp   => 'N'
        ,Pin_Only_Unsent    => 'Y'
        ,Pin_debug_flag     =>  '2'
        );
end;


select * from dual;