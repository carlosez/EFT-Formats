#/*=========================================================================+
#|  Copyright (c) 2012 Entrustca Centro America, San Salvador, El Salvador  |
#|                         ALL rights reserved.                             |
#+==========================================================================+
#|                                                                          |
#| FILENAME                                                                 |
#|     XXSV_AP011_00008.sh                                                  |
#|                                                                          |
#| DESCRIPTION                                                              |
#|    Shell Script para la instalacion de parches - Proyecto TIGO           |
#|                                                                          |
#| SOURCE CONTROL                                                           |
#|    Version: %I%                                                          |
#|    Fecha  : %E% %U%                                                      |
#|                                                                          |
#| HISTORY                                                                  |
#|    25-May-2014  C.Torres     Created   Entrustca                         |
#+==========================================================================*/


echo ''
echo '                          Oracle LAD eStudio                          '
echo '        Copyright (c) 2012 Entrustca Centro America San Salvador      '
echo '                        All rights reserved.                          '
echo '       Starting installation process for patch XXSV_AP011_00008       '

# FUNCIONES
read_db_pwd ()
{
    stty -echo # Deshabilito el ECO del Teclado

    PASSWORD_OK="No"

    while [ "${PASSWORD_OK}" != "Yes" ]
    do
        # Leo la contraseña del usuario de BD
        DB_PASS='' # Inicializo la Variable de Retorno

        while [ -z "${DB_PASS}" ]
        do
            echo -n "Please enter password for $1 user: "
            read DB_PASS
            echo
        
            if [ -z "${DB_PASS}" ]
            then
                echo "The password entered is null."
            fi

        done

        sqlplus -S /nolog <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
conn $1/$DB_PASS
EOF

        if [ "$?" != "0" ]
        then
            echo "The $1 password entered is incorrect."
        else
            PASSWORD_OK="Yes"
        fi
    done

    stty echo # Rehabilito el ECO del Teclado
}

copy_file ()
{
    if [ -f $1/$3 ]
    then
        if [ -f $2/$3 ]
        then
            mv $2/$3 $2/$3_bak$(date +%Y%m%d%H%M%S)
        fi

        cp $1/$3 $2/
    else
        echo "File $1/$3 does not exist"
    fi
}

# COMIENZO DE INSTALACION DEL PARCHE



# Ingreso de la contraseña para el usuario APPS. Usar funcion read_db_pwd $user
read_db_pwd "APPS"
APPS_PASS=$DB_PASS

# Ingreso de pass para el usuario BOLINF. Usar funcion read_db_pwd $user
read_db_pwd "BOLINF"
BOLINF_PASS=$DB_PASS

<<'COMMENT'
echo 'Copyng Forms to XBOL_TOP/forms/ '
copy_file au/forms $XBOL_TOP/forms/ESA XX_AP_EPAYMENTS.fmb
copy_file au/forms $XBOL_TOP/forms/US XX_AP_EPAYMENTS.fmb
copy_file au/forms $XBOL_TOP/forms/F XX_AP_EPAYMENTS.fmb
echo 'Copyng Host Executables'
copy_file xbol/bin $XBOL_TOP/bin XX_EFT_MOVE_FILE.prog

# CREACION de Tablas BOLINF
echo 'Ejecutando Creacion de Tablas y Paquetes en BOLINF'
sqlplus bolinf/$BOLINF_PASS @sql/XX_AP_EFT_FORMATS.sql
sqlplus bolinf/$BOLINF_PASS @sql/XX_AP_EFT_FORMAT_DEFINITIONS.sql

# Creacion de Secuencias
sqlplus bolinf/$BOLINF_PASS @sql/SEQUENCES.sql

# CREACION de Paquetes BOLINF
sqlplus bolinf/$BOLINF_PASS @sql/XX_AP_EFT_FORMATS_PKG.pks
sqlplus bolinf/$BOLINF_PASS @sql/XX_AP_EFT_FORMATS_PKG.pkb
sqlplus bolinf/$BOLINF_PASS @sql/XX_AP_EFT_FORMATS_UTL.pks
sqlplus bolinf/$BOLINF_PASS @sql/XX_AP_EFT_FORMATS_UTL.pkb

# Concecion de permisos
sqlplus bolinf/$BOLINF_PASS @sql/grants_from_bolinf.sql

# Creacion de Directorio Logico
sqlplus apps/$APPS_PASS @sql/XXSV_FILE_ELECTRONIC_DIR.sql

# Creacion Sinonimos 
sqlplus apps/$APPS_PASS @sql/synonyms_apps.sql

COMMENT

# Carga Concurrentes.
echo 'Carga de Concurrentes'


export NLS_LANG="LATIN AMERICAN SPANISH_AMERICA.WE8ISO8859P1"
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/ES_XX_AP_EFT_TRANS_BNKFILE.ldt CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/ES_XX_EFT_MOVE_FILE.ldt CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/ES_XXAPUNLOCKPAYMENT.ldt CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/ES_XX_AP_PAY_REG.ldt CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/ES_XXMIGRATEEFTFORMAT.ldt CUSTOM_MODE=FORCE

export NLS_LANG="American_America.WE8ISO8859P1"
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/US_XX_AP_EFT_TRANS_BNKFILE.ldt CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/US_XX_EFT_MOVE_FILE.ldt CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/US_XXAPUNLOCKPAYMENT.ldt CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/US_XX_AP_PAY_REG.ldt CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct xbol/admin/import/US_XXMIGRATEEFTFORMAT.ldt CUSTOM_MODE=FORCE

# Carga De Jeugo de Valores
export NLS_LANG="LATIN AMERICAN SPANISH_AMERICA.WE8ISO8859P1"
FNDLOAD apps/$APPS_PASS O Y UPLOAD $FND_TOP/patch/115/import/afffload.lct ES_XX_AP_PAY_REG_TITLE_REPORT.ldt
export NLS_LANG="American_America.WE8ISO8859P1"
FNDLOAD apps/$APPS_PASS O Y UPLOAD $FND_TOP/patch/115/import/afffload.lct US_XX_AP_PAY_REG_TITLE_REPORT.ldt

<<'COMMENT'
# Carga Request Group.
echo 'Carga de Request Group'
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct admin/import/RQ_All_Reports_Payables.ldt - CUSTOM_MODE=FORCE


# Carga Menu.
echo 'Carga Menu'
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afsload.lct $XBOL_TOP/admin/import/AP_NAVIGATE_GUI12_MN.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE="FORCE"


echo 'Carga de Ejecutable'


instal = pwd
cd $XBOL_TOP/bin
#chmod 775 XX_EFT_MOVE_FILE.prog
ln -s $FND_TOP/bin/fndcpesr XX_EFT_MOVE_FILE.prog
cd $instal
ls -al

# compila forma
cd  $XBOL_TOP/forms/ESA
frmcmp_batch module=XX_AP_EPAYMENTS.fmb userid=apps/$APPS_PASS module_type=form compile_all=special
cd  $XBOL_TOP/forms/US
frmcmp_batch module=XX_AP_EPAYMENTS.fmb userid=apps/$APPS_PASS module_type=form compile_all=special
cd  $XBOL_TOP/forms/F
frmcmp_batch module=XX_AP_EPAYMENTS.fmb userid=apps/$APPS_PASS module_type=form compile_all=special

COMMENT

echo '+------------------------------------------------------------------------------+'
echo '|                                                                              |'
echo '|                                                                              |'
echo '|               Instalation Complete, Please Check Log Files                   |'
echo '|                                                                              |'
echo '|                                                                              |'
echo '+------------------------------------------------------------------------------+'

