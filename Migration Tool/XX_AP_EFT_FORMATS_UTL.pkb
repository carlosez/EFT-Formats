CREATE OR REPLACE PACKAGE XX_AP_EFT_FORMATS_UTL authid current_user as

procedure migrate_format( pin_old_format varchar2 , pin_new_format_name varchar2);

end;

create or replace package body XX_AP_EFT_FORMATS_UTL as

procedure migrate_format( pin_old_format varchar2 , pin_new_format_name varchar2) is




cursor c_format_definition (pin_id_master number) return XX_AP_EFT_FORMAT_DEFINITIONS%rowtype is 
    select 
     dt.ID_FILE_FORMAT  DEFINITION_ID
    ,dt.ID_MASTER       FORMAT_ID
    ,dt.FIELD_NAME          FIELD_NAME
    ,dt.TYPE_VALUE          TYPE_VALUE
    , replace(replace(dt.CONSTANT_VALUE,'\E',' '),'\N','')  CONSTANT_VALUE
    ,dt.SECUENCE    SECUENCE
    ,dt.START_POSITION  START_POSITION
    ,dt.END_POSITION  END_POSITION
    ,dt.DATA_TYPE  DATA_TYPE
    ,dt.FORMAT  FORMAT_MODEL
    ,ascii(replace(dt.PADDING_CHARACTER,'E',' ')) PADDING_CHARACTER
    ,decode(nvl(dt.NEEDS_PADDING,'N'),'Y', dt.DIRECTION_PADDING, 'N','NONE')  DIRECTION_PADDING
    ,dt.SQL_STATEMENT  SQL_STATEMENT
    ,decode(dt.PART_OF_FILE, 'TRX','BODY','FOOTER','TRAILER',dt.PART_OF_FILE)  PART_OF_FILE
    ,dt.CREATED_BY  CREATED_BY
    ,dt.CREATION_DATE  CREATION_DATE
    ,dt.LAST_UPDATED_BY  LAST_UPDATED_BY
    ,dt.LAST_UPDATE_DATE  LAST_UPDATE_DATE
     from XX_SV_AP_EPAYMENT_DETAIL Dt
     where dt.id_master = pin_id_master
     ;
     
 v_master_id number;
 v_count number;
 t_format_header  XX_AP_EFT_FORMATS%rowtype;
 t_format_definition XX_AP_EFT_FORMAT_DEFINITIONS%rowtype;

begin
    
    dbms_output.put_line('Begin Procedure' ) ;
    
    begin
        select 
             ms.id_master FORMAT_ID                     --+ 1
            ,ms.FORMAT_NAME   FORMAT_NAME       --+ 2
            ,decode( MS.TYPE_TEXT_FILE, 'DELIMITED', 'DELIMITED', 'POSITIONS' , 'FIXED_WIDTH')  FORMAT_TYPE --+ 3
            , ascii(decode(MS.DELIMITER,'T',chr(9),MS.DELIMITER)) ACII_DELIMITER        --+ 4
            , null FILE_EXTENSION           --+ 5
            , enable ENABLE_FLAG            --+ 6
            , ms.CREATED_BY                 --+ 7
            ,ms.CREATION_DATE               --+ 8
            ,ms.LAST_UPDATED_BY             --+ 9
            ,ms.LAST_UPDATE_DATE            --+ 10
        into t_format_header
        from XX_SV_AP_EPAYMENT_MASTER ms
        where upper(trim(ms.FORMAT_NAME)) = upper(trim(pin_old_format))
        ;
        
        v_count := sql%rowcount;
        dbms_output.put_line('Selected Rows ' || to_char(v_count,'9999999') ) ;
        dbms_output.put_line('Selected program ' || TO_CHAR(t_format_header.FORMAT_NAME ) ) ;
    exception when no_data_found then 
        dbms_output.put_line('Not data found ' || TO_CHAR(t_format_header.FORMAT_NAME ) ) ;
      WHEN OTHERS THEN 
      dbms_output.put_line('ERROR '|| SQLERRM || TO_CHAR(t_format_header.FORMAT_NAME ) ) ; 
    end;

    
    IF T_FORMAT_HEADER.FORMAT_NAME IS NOT NULL THEN 
         dbms_output.put_line('Begin Detail Program ' ) ;
        v_master_id := T_FORMAT_HEADER.FORMAT_ID;
        T_FORMAT_HEADER.FORMAT_NAME  := pin_new_format_name;
        
        SELECT XX_AP_EFT_FORMATS_S.NEXTVAL INTO T_FORMAT_HEADER.FORMAT_ID FROM DUAL;    
            
        begin
            insert into XX_AP_EFT_FORMATS values T_FORMAT_HEADER;
            
            for r_definition in c_format_definition(v_master_id ) loop
                
                 dbms_output.put_line('DEFF  ' || r_definition.FIELD_NAME  ) ;
                 
                t_format_definition := r_definition;
                
                SELECT XX_AP_EFT_FORMAT_DEFINITIONS_S.NEXTVAL , T_FORMAT_HEADER.FORMAT_ID  
                  INTO  t_format_definition.definition_id,  t_format_definition.FORMAT_ID FROM DUAL;    
                
                insert into XX_AP_EFT_FORMAT_DEFINITIONS values t_format_definition;
            end loop;
        end;

    END IF;

end;


end;