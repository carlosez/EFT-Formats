#/*=========================================================================+
#|  Copyright (c) 2012 Oratechla, San Salvador, El Salvador                 |
#|                         ALL rights reserved.                             |
#+==========================================================================+
#|                                                                          |
#| FILENAME                                                                 |
#|     XX_AP_EPAYMENTS.sh                                            |
#|                                                                          |
#| DESCRIPTION                                                              |
#|    Shell Script para la instalacion de parches - Proyecto TIGO           |
#|                                                                          |
#| SOURCE CONTROL                                                           |
#|    Version: %I%                                                          |
#|    Fecha  : %E% %U%                                                      |
#|                                                                          |
#| HISTORY                                                                  |
#|    20-Dec-2012  E.Esquivel     Created   Entrustca                       |
#+==========================================================================*/


echo ''
echo '                          Oracle LAD eStudio                          '
echo '           Copyright (c) 2012 Oracle San Salvador, El Salvador        '
echo '                        All rights reserved.                          '
echo 'Starting installation process for patch XX_AP_EPAYMENTS        '
echo

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

# Ingreso de la contraseña para el usuario BOLINF. Usar funcion read_db_pwd $user
read_db_pwd "BOLINF"
BOLINF_PASS=$DB_PASS

# Copia de los Objetos. Usar funcion copy_file $origen $destino $file
echo 'Copying objects SQL to $XBOL_TOP'

copy_file xbol/sql $XBOL_TOP/sql XX_SV_AP_EPAYMENT_MASTER.sql
copy_file xbol/sql $XBOL_TOP/sql XX_SV_AP_EPAYMENT_DETAIL.sql
copy_file xbol/sql $XBOL_TOP/sql XX_SV_EPAYMENT_Header.sql
copy_file xbol/sql $XBOL_TOP/sql XX_SV_EPAYMENT_body.sql


# Copia de los Imports
echo 'Copying objects LDT to $XBOL_TOP'

copy_file xbol/admin/import $XBOL_TOP/admin/import XX_AP_EPAYMENTS_FUNC.ldt
copy_file xbol/admin/import $XBOL_TOP/admin/import XX_AP_EPAYMENTS_FRM.ldt
copy_file xbol/admin/import $XBOL_TOP/admin/import AP_NAVIGATE_GUI12_MN.ldt


copy_file xbol/admin/import $XBOL_TOP/admin/import C_XX_SV_FLEX_BANK_FILE.ldt
copy_file xbol/admin/import $XBOL_TOP/admin/import C_XXSVUPDATECHECKSTATUS.ldt
copy_file xbol/admin/import $XBOL_TOP/admin/import F_AP_CHECKS.ldt
copy_file xbol/admin/import $XBOL_TOP/admin/import F_CE_PAYMENT_DOCUMENTS_SV.ldt
copy_file xbol/admin/import $XBOL_TOP/admin/import F_PO_VENDOR_SITES.ldt
copy_file xbol/admin/import $XBOL_TOP/admin/import R_All_Reports.ldt
# COPIA FORMAS
#copia los  rdfs

copy_file au/forms $XBOL_TOP/forms/ESA XX_AP_EPAYMENTS.fmb
copy_file au/forms $XBOL_TOP/forms/US XX_AP_EPAYMENTS.fmb
copy_file au/forms $XBOL_TOP/forms/F XX_AP_EPAYMENTS.fmb


# CREACION de Tablas BOLINF
echo 'Ejecutando Creacion de Tablas y Paquetes en BOLINF'
sqlplus bolinf/$BOLINF_PASS @$XBOL_TOP/sql/XX_SV_AP_EPAYMENT_MASTER.sql
sqlplus bolinf/$BOLINF_PASS @$XBOL_TOP/sql/XX_SV_AP_EPAYMENT_DETAIL.sql

# CREACION de Tablas Paquetes BOLINF
sqlplus bolinf/$BOLINF_PASS @$XBOL_TOP/sql/XX_SV_EPAYMENT_Header.sql
sqlplus bolinf/$BOLINF_PASS @$XBOL_TOP/sql/XX_SV_EPAYMENT_body.sql

# Carga Concurrentes.
echo 'Carga de Concurrentes'
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $XBOL_TOP/admin/import/C_XX_SV_FLEX_BANK_FILE.ldt  - CUSTOM_MODE=FORCE
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $XBOL_TOP/admin/import/C_XXSVUPDATECHECKSTATUS.ldt  - CUSTOM_MODE=FORCE

# Carga de FlexFields
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $XBOL_TOP/admin/import/F_AP_CHECKS.ldt
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $XBOL_TOP/admin/import/F_CE_PAYMENT_DOCUMENTS_SV.ldt
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $XBOL_TOP/admin/import/F_PO_VENDOR_SITES.ldt

# Carga Request Group.
echo 'Carga de Request Group'
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $XBOL_TOP/admin/import/R_All_Reports.ldt - CUSTOM_MODE=FORCE



# Carga form y function.

FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afsload.lct $XBOL_TOP/admin/import/XX_AP_EPAYMENTS_FRM.ldt 
## ------------- Forms Function ------------------
echo 'form y function'

FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afsload.lct $XBOL_TOP/admin/import/XX_AP_EPAYMENTS_FUNC.ldt 

# Carga Menu.
echo 'Carga Menu'
FNDLOAD apps/$APPS_PASS 0 Y UPLOAD $FND_TOP/patch/115/import/afsload.lct $XBOL_TOP/admin/import/AP_NAVIGATE_GUI12_MN.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE="FORCE"

echo ' '
# Carga Template.


echo 'Carga de Data Definition'
#####################################################################################
# UPLOAD TEMPLATES  XML y RTF
#####################################################################################
cd au/template
# DATA DEFINITION

# compila forma
cd  $XBOL_TOP/forms/ESA
frmcmp_batch module=XX_AP_EPAYMENTS.fmb userid=apps/$APPS_PASS module_type=form compile_all=special
cd  $XBOL_TOP/forms/US
frmcmp_batch module=XX_AP_EPAYMENTS.fmb userid=apps/$APPS_PASS module_type=form compile_all=special
cd  $XBOL_TOP/forms/F
frmcmp_batch module=XX_AP_EPAYMENTS.fmb userid=apps/$APPS_PASS module_type=form compile_all=special


	
echo 'Carga de Template'
# TEMPLATE

cd ..
cd ..
echo 'Installation Complete. Please check log files.'

