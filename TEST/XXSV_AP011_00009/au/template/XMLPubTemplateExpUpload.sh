#/*=========================================================================+
#|  Copyright (c) 2012 Oratechla, San Salvador, El Salvador                 |
#|                         ALL rights reserved.                             |
#+==========================================================================+
#|                                                                          |
#| FILENAME                                                                 |
#|     XMLPubTemplateExpUpload.sh                                           |
#|                                                                          |
#| DESCRIPTION                                                              |
#|    Shell Script para la instalacion de Templates - Proyecto TIGO         |
#|                                                                          |
#| SOURCE CONTROL                                                           |
#|    Version: %I%                                                          |
#|    Fecha  : %E% %U%                                                      |
#|                                                                          |
#| HISTORY                                                                  |
#|    06-Sep-2012  E.Monsalve     Created   Oratechla                       |
#+==========================================================================*/
#!/usr/bin/ksh

 
APPS_PWD=$1
LOB_TYPE=$2
APPS_SHORT_NAME=$3
LOB_CODE=$4
LANGUAGE=$5
TERRITORY=$6
XDO_FILE_TYPE=$7
FILE_NAME=$8



set +e
echo "test nawk" | nawk '{ print $0 }' 2> /dev/null
if [ $? -eq 0 ]
then
   AWK=nawk
else
   AWK=awk
fi;
set -e
TNSPING=tnsping

NEW_TWO_TASK=`echo $TWO_TASK | awk -F"_" '{ print $1 }'`
export $NEW_TWO_TASK

if [ "$TWO_TASK" != "$NEW_TWO_TASK" ]
then
   TWO_TASK=`echo ${NEW_TWO_TASK}"1"`
fi;

export TWO_TASK
echo TWO_TASK=$TWO_TASK

export TNSPING
DB_PORT=`$TNSPING $TWO_TASK | grep -i "ADDRESS" | $AWK -v tns_token=port -f get_tns_param.awk`
export DB_PORT
echo PORT=$DB_PORT

DB_HOST=`$TNSPING $TWO_TASK | grep -i "ADDRESS" | $AWK -v tns_token=host -f get_tns_param.awk`
export DB_HOST
echo HOST=$DB_HOST


echo APPS_PWD=$APPS_PWD
echo LOB_TYPE=$LOB_TYPE
echo APPS_SHORT_NAME=$APPS_SHORT_NAME
echo LOB_CODE=$LOB_CODE
echo LANGUAGE=$LANGUAGE
echo TERRITORY=$TERRITORY
echo XDO_FILE_TYPE=$XDO_FILE_TYPE
echo FILE_NAME=$FILE_NAME


java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPS_PWD \
-JDBC_CONNECTION $DB_HOST:$DB_PORT:$TWO_TASK \
-LOB_TYPE $LOB_TYPE \
-APPS_SHORT_NAME $APPS_SHORT_NAME \
-LOB_CODE $LOB_CODE \
-CUSTOM_MODE FORCE \
-LANGUAGE $LANGUAGE \
-TERRITORY $TERRITORY \
-XDO_FILE_TYPE $XDO_FILE_TYPE \
-FILE_NAME $FILE_NAME