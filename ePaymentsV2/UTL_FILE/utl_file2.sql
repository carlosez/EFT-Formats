DECLARE
      OUT_FILE                            UTL_FILE.FILE_TYPE;
      IN_FILE                                UTL_FILE.FILE_TYPE;
      WRITEMEASSAGE                 VARCHAR2(2000);

      lv_file_name                         VARCHAR2(100);
      p_scenario                            VARCHAR2(100) := 'EPRUEBA_';
      p_file_id                               NUMBER := 3020;
      p_diectory                            VARCHAR2(250);
      
BEGIN

       lv_file_name := p_scenario ||'_'|| TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS')||'_'||TO_CHAR(p_file_id) || '.txt';
       
       --
--       select  trim(description)
--          into p_diectory
--        from apps.fnd_lookup_values_vl 
--        where lookup_type = 'XX_FND_WS_PARAMETERS'
--           and lookup_code = 'XXSV_PAYELECT_DIR';
           
           p_diectory := '/interface/j_mili/SMILII/archive/TigoSV/outgoing/pagos_citi';
           
           
       dbms_output.PUT_LINE('Directory  : '||p_diectory);
       dbms_output.PUT_LINE('lv_file_name  : '||lv_file_name);
       
       if p_diectory is not null then
          OUT_FILE := UTL_FILE.FOPEN (p_diectory, lv_file_name, 'W');
          WRITEMEASSAGE  := 'This is created for testing purpose \n' || ' \n This is the second line';
          UTL_FILE.PUTF(OUT_FILE,WRITEMEASSAGE); 
          UTL_FILE.FFLUSH(OUT_FILE);
          UTL_FILE.FCLOSE(OUT_FILE);
       else
          dbms_output.PUT_LINE('Error directory  Message Is: '||SQLERRM);
       end if;
EXCEPTION
WHEN UTL_FILE.INVALID_PATH THEN
                             UTL_FILE.fclose (OUT_FILE);
                             dbms_output.PUT_LINE('File Error : Invalid Path: '||SQLERRM);
                   WHEN UTL_FILE.INVALID_MODE THEN
                            UTL_FILE.fclose (OUT_FILE);
                            dbms_output.PUT_LINE('File Error : Invalid Mode: '||SQLERRM);
                   WHEN UTL_FILE.INVALID_OPERATION THEN
                            UTL_FILE.fclose (OUT_FILE);
                            dbms_output.PUT_LINE('File Error : Invalid Operation: '||SQLERRM);
                   WHEN UTL_FILE.INVALID_FILEHANDLE THEN
                            UTL_FILE.FCLOSE(OUT_FILE);
                            dbms_output.PUT_LINE('File Error : Invalid File Handle: '||SQLERRM);
                   WHEN UTL_FILE.READ_ERROR THEN
                             UTL_FILE.FCLOSE(OUT_FILE);
                             dbms_output.PUT_LINE('File Error : Read Error: '||SQLERRM);
                   WHEN OTHERS THEN
                             UTL_FILE.FCLOSE(OUT_FILE);
                            dbms_output.PUT_LINE('Error Message Is: '||SQLERRM);
END;
