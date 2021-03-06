#
# Script: XX_EFT_MOVE_FILE.prog 
#--
#-- Author: Carlos Torres
#--
#-- Description: This program will be used to Move Payments Files
#--
#-- Change History:
#---------------------------------------------------------------
#-- Date           Who                Reason        --
#---------------------------------------------------------------
#-- 27-MAY-2014    CTORRES            Initial Version
#---------------------------------------------------------------#
CURR_TIMESTAMP=`date "+%d-%h-%Y_%H-%M-%S"`
#----- Standard Parameters: -----#
PROGRAM_NAME=$0 #Execution File Name	 #
SQL_USER=$1 	#Oracle Applications Username/Password #
CREATED_BY=$2 	#Application userid           #
CREATE_USER=$3 	#Application username         #
REQUEST_ID=$4	#Conucurrent Request_id	 #
#----- User Parameters: -----#
P_SOURCE=$5 # Directory where the file is placed #
P_DESTINATION=$6 # Directory where the file will be moved    #
P_FILE=$7  # File Name  #

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
        echo "+---------------------------------------------------------------------------+"
        cp $1/$3 $2/
        echo " Copping File   : $3 "
        echo " From Directory : $1 "
		echo " Into Directory : $2 "
		echo "+---------------------------------------------------------------------------+"
        rm $1/$3
        echo " Deleting File  : $3 "
		echo " From Directory : $1 "
		echo "+---------------------------------------------------------------------------+"
    else
        echo "File $1/$3 does not exist"
        echo "+---------------------------------------------------------------------------+"
    fi
}

copy_file $P_SOURCE $P_DESTINATION $P_FILE
##
#echo "***********************"
echo "+---------------------------------------------------------------------------+"
echo " Listing Files "
echo " In Directory : ${P_DESTINATION}  "
echo "+---------------------------------------------------------------------------+"
cd $P_DESTINATION
ls *

exit 0