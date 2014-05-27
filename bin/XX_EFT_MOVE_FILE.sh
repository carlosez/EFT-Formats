#
# Script: XXINVTRMISC.prog 
#--
#-- Author: Deepka Morey
#--
#-- Description: This program will be used to  call SQL*Loader
#--  utility and also archive the data file.
#--
#-- Change History:
#---------------------------------------------------------------
#-- Date           Who                Reason        --
#---------------------------------------------------------------
#-- 09-NOV-2011    DMorey               Initial Version
#-- 15-NOV-2011    MGupta               Modified to Insert file 
#--                                     name in the table
#---------------------------------------------------------------#
CURR_TIMESTAMP=`date "+%d-%h-%Y_%H-%M-%S"`
#----- Standard Parameters: -----#
PROGRAM_NAME=$0 #Execution File Name	 #
SQL_USER=$1 	#Oracle Applications Username/Password #
CREATED_BY=$2 	#Application userid           #
CREATE_USER=$3 	#Application username         #
REQUEST_ID=$4	#Conucurrent Request_id	 #
#----- User Parameters: -----#
P_SOURCE=$5
P_DESTINATION=$6
P_FILE=$7

#copy_file xbol/admin/import $XBOL_TOP/admin/import XX_AR_REPCAJ_RES.ldt
copy_file ()
{
    if [ -f $1/$3 ]
    then
        if [ -f $2/$3 ]
        then
            echo "File $2/$3 exist, back up created  $3_bak${CURR_TIMESTAMP} "
            mv $2/$3 $2/$3_bak$CURR_TIMESTAMP
        fi

        cp $1/$3 $2/
        rm $1/$3
    else
        echo "File $1/$3 does not exist"
    fi
}

##
echo "------------------------------------------"
echo " Moving File : $1/$3 "
echo "------------------------------------------"
##

copy_file $P_SOURCE $P_DESTINATION $P_FILE
##
#echo "***********************"
echo " Listado de Archivos "
#echo "***********************"
ls $P_DESTINATION/*
#echo "***********************"
#echo "*        FIN          *"
#echo "***********************"

exit 0