-- fnd_web_sec

select * from XX_AP_EFT_FORMATS
;

select * from XX_AP_EFT_FORMAT_definitions
where format_id = 3;


declare 
cursor Detalles is
select  dt.rowid,dt.* from XX_AP_EFT_FORMAT_definitions dt;
begin

    for x in detalles loop
        if X.DEFINITION_ID is null then
        
        select XX_AP_EFT_FORMAT_definitions_s.nextval into X.DEFINITION_ID from dual;
        update XX_AP_EFT_FORMAT_definitions df set df.DEFINITION_ID = x.DEFINITION_ID
        where df.rowid = x.rowid; 
        end if;
    end loop;
end;


select * from XX_AP_EFT_FORMAT_definitions