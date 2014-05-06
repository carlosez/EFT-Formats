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
        ,Pin_End_Date       => '2013/12/30 00:00:00'
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

--
--
--SELECT  MS.FORMAT_TYPE                      --+ 1
--       ,chr(MS.ASCII_DELIMITER)  DELIMITER  --+ 2
--       ,DT.TYPE_VALUE                       --+ 3
--       ,DT.CONSTANT_VALUE                   --+ 4
--       ,DT.SECUENCE                         --+ 5
--       ,DT.START_POSITION                   --+ 6
--       ,DT.END_POSITION                     --+ 7
--       ,DT.DATA_TYPE                        --+ 8
--       ,DT.FORMAT_MODEL                     --+ 9
--       ,chr( nvl( DT.PADDING_CHARACTER, 32  )) PADDING_CHARACTER --+ 10
--       ,decode(FORMAT_TYPE , 'DELIMITED', DT.DIRECTION_PADDING , 'FIXED_WIDTH',  decode( nvl(DT.DIRECTION_PADDING,'NONE'),'NONE','RIGTH',DT.DIRECTION_PADDING )  ) DIRECTION_PADDING                --+ 11
--       ,decode(FORMAT_TYPE , 'FIXED_WIDTH','Y', decode(DT.DIRECTION_PADDING,'NONE','N','RIGTH','Y', 'LEFT', 'Y') )NEEDS_PADDING --+ 12
--       ,DT.SQL_STATEMENT                    --+ 13
--  FROM  XX_AP_EFT_FORMAT_DEFINITIONS DT
--       ,XX_AP_EFT_FORMATS MS
-- WHERE ms.format_id = :g_FORMAT_USED
--   AND DT.format_id = MS.format_id
--   AND MS.ENABLE_FLAG = 'Y'
--   AND DT.PART_OF_FILE = :P_PART
-- ORDER BY DT.SECUENCE ASC;
-- 
-- select trim(TO_CHAR(:NUMBER_VAL,:FORMAT)) from dual;
-- 

-- SELECT SUBSTR(  replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(upper(  nvl(CH.REMIT_TO_SUPPLIER_NAME, ch.VENDOR_NAME)    ), CHR(13), null), CHR(10),null), 'Ú', 'U'), 'Ó', 'O'), 'Í', 'I'), 'É', 'E'), 'Á', 'A'),'À','A'),'È','E'),'Ì','I'),'Ò','O'),'Ù','U'),'Ñ','N'),'#',' '),'@',' '),'^',' '),'*',' '),'%',' '),'&',' '),'\',' '),'|',' '),'!',' '),'~',' '),'?',' '),'}',' '),'{',' '),'[',' '),']',' '),chr(39),' '),'`',' '),'/',' '),'Ü','U'),1,34)   vendor   FROM ap.AP_CHECKS_ALL CH   where ch.CHECK_ID = :IDCHECK
-- 
--  SELECT SUBSTR(  replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(upper(  nvl(CH.REMIT_TO_SUPPLIER_NAME, ch.VENDOR_NAME)    ), CHR(13), null), CHR(10),null), 'Ú', 'U'), 'Ó', 'O'), 'Í', 'I'), 'É', 'E'), 'Á', 'A'),'À','A'),'È','E'),'Ì','I'),'Ò','O'),'Ù','U'),'Ñ','N'),'#',' '),'@',' '),'^',' '),'*',' '),'%',' '),'&',' '),'\',' '),'|',' '),'!',' '),'~',' '),'?',' '),'}',' '),'{',' '),'[',' '),']',' '),chr(39),' '),'`',' '),'/',' '),'Ü','U'),35,34)   vendor   FROM ap.AP_CHECKS_ALL CH   where ch.CHECK_ID = :IDCHECK
-- 


 APPS.FND_REQUEST .SUBMIT_REQUEST
