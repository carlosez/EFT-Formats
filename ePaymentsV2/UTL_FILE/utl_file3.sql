DECLARE
      OUT_FILE                            UTL_FILE.FILE_TYPE;
      IN_FILE                                UTL_FILE.FILE_TYPE;
      WRITEMEASSAGE                 VARCHAR2(2000);

      lv_file_name                         VARCHAR2(100);
      p_scenario                            VARCHAR2(100) := 'EPRUEBA_';
      p_file_id                               NUMBER := 3020;
BEGIN

       lv_file_name := p_scenario ||'_'|| TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS')||'_'||TO_CHAR(p_file_id) || '.txt';
  
       --
       
       OUT_FILE := UTL_FILE.FOPEN ('XXSV_FILE_ELECTRONIC_DIR', lv_file_name, 'w');
       WRITEMEASSAGE  := 'This is created for testing purpose \n' || ' \n This is the second line';
       UTL_FILE.PUTF(OUT_FILE,WRITEMEASSAGE); 
       UTL_FILE.FFLUSH(OUT_FILE);
       UTL_FILE.FCLOSE(OUT_FILE);
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
