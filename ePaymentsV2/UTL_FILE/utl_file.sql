DECLARE
      OUT_FILE                            UTL_FILE.FILE_TYPE;
      IN_FILE                                UTL_FILE.FILE_TYPE;
      WRITEMEASSAGE                 VARCHAR2(2000);

      lv_file_name                         VARCHAR2(100);
      p_scenario                            VARCHAR2(100) := 'EPRUEBA_';
      p_file_id                               NUMBER := 3020;
BEGIN

       lv_file_name := p_scenario ||'_'|| TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS')||'_'||TO_CHAR(p_file_id) || '.csv';
  
       --
       
       OUT_FILE := UTL_FILE.FOPEN ('XXSV_FILE_ELECTRONIC_DIR', lv_file_name, 'W');
       WRITEMEASSAGE  := 'This is created for testing purpose \n' || ' \n This is the second line';
       UTL_FILE.PUTF(OUT_FILE,WRITEMEASSAGE); 
       UTL_FILE.FFLUSH(OUT_FILE);
       UTL_FILE.FCLOSE(OUT_FILE);
EXCEPTION
      WHEN OTHERS THEN
                UTL_FILE.FCLOSE(OUT_FILE);
END;
