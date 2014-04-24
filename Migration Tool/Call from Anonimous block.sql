
declare
cursor formatos is
select * from XX_SV_AP_EPAYMENT_MASTER;
begin

for x in formatos loop
XX_AP_EFT_FORMATS_UTL.MIGRATE_FORMAT( x.FORMAT_NAME, x.FORMAT_NAME || ' (AUTO)');
end loop;
commit;
end;