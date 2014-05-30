CREATE OR REPLACE PACKAGE BOLINF.XX_AP_EFT_FORMATS_UTL authid current_user as


procedure migrate_format
                        (Errbuf     Out             Varchar2       --+ 1
                        ,Retcode    Out             Varchar2       --+ 2
                        ,pin_old_format             varchar2 
                        ,pin_new_format_name        varchar2
                        );

end;
/
exit
/