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

# Creacion de Directorio Logico
echo '+---------------------------------------------------------------------------+'
echo 'Creacion de Directorio Logico'
echo 'Ejecutando XXSV_FILE_ELECTRONIC_DIR.sql'

sqlplus bolinf/$BOLINF_PASS @xbol/sql/XXSV_FILE_ELECTRONIC_DIR.sql


echo '+------------------------------------------------------------------------------+'
echo '|                                                                              |'
echo '|                                                                              |'
echo '|               Instalation Complete, Please Check Log Files                   |'
echo '|                                                                              |'
echo '|                                                                              |'
echo '+------------------------------------------------------------------------------+'

