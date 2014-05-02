declare
v_Errbuf varchar2(400);
v_retcode varchar2(30);
fecha_hora varchar2(300):='ctorres';
begin
      fnd_file.
      put_names ('test' || fecha_hora || '.log',
                 'test' || fecha_hora || '.out',
                 'XXSV_FILE_ELECTRONIC_DIR');

fnd_file.put_line(fnd_file.log,to_char(sysdate,'yyyy-mm-dd_hh24-mi-ss'));
XX_AP_EFT_FORMATS_PKG.MAIN(
         Errbuf             => v_Errbuf
        ,Retcode            => v_retcode
        ,pin_Bank_Acc       => ''
        ,Pin_Pay_Document   => 2552
        ,Pin_Format_used    => 14
        ,Pin_Doc_Ini        => ''
        ,Pin_Doc_Fin        => ''
        ,Pin_Start_Date     => '2013/12/20 00:00:00'
        ,Pin_End_Date       => '2013/12/26 00:00:00'
        ,Pin_Base_Amount    => 0
        ,Pin_Top_Amount     => 99999999
        ,pin_process_type   => 'FINAL'
        ,Pin_Transfer_Ftp   => 'N'
        ,Pin_Only_Unsent    => 'N'
        ,Pin_debug_flag     => '1'
        );
fnd_file.put_line(fnd_file.log,to_char(sysdate,'yyyy-mm-dd_hh24-mi-ss'));

        fnd_file.close;
end;


-- Queries
--select * from ce_payment_documents
--where PAYMENT_DOCUMENT_ID = 2552
--select * from all_directories



