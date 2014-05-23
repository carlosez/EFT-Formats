# $Header: XXINVTRMISC.prog 115.02 2007/05/22 dmorey 
#-------------------------------------------------------------#
#-- Program: Standard Interface Loader shell script
#--
#-- Script: XXINVTRMISC.prog 
#--
#-- Author: Deepka Morey
#--
#-- Description: This program will be used to  call SQL*Loader
#--  utility and also archive the data file.
#--
#-- Change History:
#---------------------------------------------------------------
#-- Date	    Who		                Reason        --
#---------------------------------------------------------------
#-- 09-NOV-2011    DMorey               Initial Version
#-- 15-NOV-2011    MGupta               Modified to Insert file 
#--                                     name in the table
#---------------------------------------------------------------#
CURR_TIMESTAMP=`date "+%d-%h-%Y-%H:%M:%S"`
#----- Standard Parameters: -----#
PROGRAM_NAME=$0 #Execution File Name	 #
SQL_USER=$1 	#Oracle Applications Username/Password #
CREATED_BY=$2 	#Application userid           #
CREATE_USER=$3 	#Application username         #
REQUEST_ID=$4	#Conucurrent Request_id	 #
#----- User Parameters: -----#
P_DATA_LOC=$5
P_DATA_FILE=$6
P_CONTROL_LOC=$7
P_CONTROL_FILE=$8
P_ARCHIVE_PATH=$9

echo "CHECK ************ $P_CONTROL_LOC $7"
##################Changes done by Mishu to use file name##################################
#
P_DATA_FILE_BKP=$6	#back up of P_DATA_FILE
#
##################End Of changes done by Mishu ###########################################

BAD_FILE=$APPLCSF/$APPLOUT/o$REQUEST_ID.bad 
DISCARD_FILE=$APPLCSF/$APPLOUT/o$REQUEST_ID.dis 
LOG_FILE=$APPLCSF/$APPLLOG/l$REQUEST_ID.log 
DASH=_
P_ARCHIVE_FILE=${P_ARCHIVE_PATH}/${P_DATA_FILE}

if [ $# -lt 8 ]
then
   echo ""
   echo "$0: too few arguments specified."
   echo ""
   echo "Usage: $0 <user/pwd@instance> <created_by> \\ " 
   echo "          <apps_user_name> <request_id> " 
   echo "          <data_folder> <data_file>  " 
   echo "          <control_file_folder> <control_file> " 
   echo "          <archive_path>                      " 
   echo "" 
   echo ""
   exit 1
fi

#------------------------------------------------------------#
##   Building absolute path from location and filename
#------------------------------------------------------------#
     P_DATA_FILE_LOC=${P_DATA_LOC} 
     P_DATA_FILE=${P_DATA_FILE_LOC}/${P_DATA_FILE}
     echo " Validating In-File Location =$P_DATA_FILE_LOC"
#------------------------------------------------------------#
##   Building absolute path from location and filename
#------------------------------------------------------------#
     P_CONTROL_FILE=${P_CONTROL_LOC}/${P_CONTROL_FILE}
     echo " Validating Control File Location =$P_CONTROL_FILE"
#----------------------------------
#-- Function Interface Home Directory
#----------------------------------
f_inf_dir ()
{  
     file_loc=$1
  
     if [ ! -d ${file_loc}  ]
     then
          echo "Directory does not exists"
          exit_code=111
         f_error $exit_code
     else
          if [ ! -w ${file_loc}  ]
          then
               echo "Directory is not writeable"
               exit_code=112
              # f_error $exit_code
          fi
     fi
}

#----------------------------------
#-- Function Validate data files
#----------------------------------
f_data_file ()
{
    data_file=$1
    if [ ! -f $data_file ] 
    then
        echo "Data file does not exists"
        exit_code=121
        f_error $exit_code
    else
        if [ ! -r ${data_file} ]
        then
            echo "Denied Read on Data File"
            exit_code=122
            f_error $exit_code
        fi
        if [ ! -s ${data_file} ]
        then
           exit_code=123
           f_error $exit_code
        fi
    fi
}

#---------------------------------------------------
#--Function Check Control file
#---------------------------------------------------
f_ctl_file ()
{ 
   ctl_file=$1
   
   if [ ! -f ${ctl_file} ] 
   then
	echo "# Control File does not exists"
        exit_code=131
        f_error $exit_code
   else
        if [ ! -r ${ctl_file} ]
        then
            echo "# Denied Read on Control File"
            exit_code=132
            f_error $exit_code
        fi
        if [ ! -s ${ctl_file} ]
        then
           exit_code=133
           f_error $exit_code
        fi
   fi
}

#---------------------------------------------------
#--- Function Validate archive path
#---------------------------------------------------
f_arc_dir ()
{
     arc_loc=$1

	 echo "Validating Archive direcotry:"$arc_loc
	 if [ "$arc_loc" = "" ]
	 then
		echo "Archive Directory not specifoed. Archiving will not be done."
	    f_error 139
		exit 0
	 else
		 if [ $P_ARCHIVE_PATH = $P_DATA_LOC ]
		 then
			echo "Archive Directory is same as Data File Directory. Archiving will not be done."
			f_error 140
		    exit 0
	     else
			 if [ ! -d ${arc_loc}  ]
			 then
				  echo "Archive Directory does not exists"
				  exit_code=141
				  f_error $exit_code
			 else
				  if [ ! -w ${arc_loc} ] 
				  then
					   echo "Archive Directory is not writeable"
					   exit_code=142
					   f_error $exit_code
				  fi
			 fi
		 fi
	 fi
}
#-------------------------------------------------#
# SQL*Loader.process.
#-------------------------------------------------#
function f_call_sqlldr
{
    sqlldr userid=$SQL_USER \
    control=$P_CONTROL_FILE \
       data=$P_DATA_FILE \
        bad=$BAD_FILE \
    discard=$DISCARD_FILE \
        log=$LOG_FILE \

     return_code="$?" 
     
	 case $return_code in
	 0) sqlldr_error=0;;
	 *) sqlldr_error=1
     esac
     echo "---------------------------------"
     echo "- Contents from SQL*Loader Log file "
     echo "";
     cat    $LOG_FILE ;
     echo "---------------------------------"
     
	if [ -s ${BAD_FILE} ] 
          then
             exit_code=177;
             f_error $exit_code;
          fi;
          if [ -s ${DISCARD_FILE} ]
          then 
             exit_code=177;
	     f_error $exit_code;
          fi;
     if test $sqlldr_error -eq "1"
     then
          echo "";
          if [ -s ${BAD_FILE} ] 
          then
             echo "--------------***************-------------------"
             echo "- Contents from SQL*Loader Bad file ";
             echo "--------------***************-------------------"
             echo "";
             fold -w 150 $BAD_FILE ;
             echo "";
          fi;
          if [ -s ${DISCARD_FILE} ]
          then 
             echo "--------------***************-------------------"
             echo "- Contents from SQL*Loader Discard file ";
             echo "--------------***************-------------------"
             echo "";
             fold -w 150 $DISCARD_FILE ;
          fi;
       exit_code=177;
       f_error $exit_code;
    fi;
}
#-------------------------------------------------#
##-- Archive function
#-------------------------------------------------#
function f_archive
{
     archive_err=0;
     arch_file=$P_ARCHIVE_FILE
	archive_file="$arch_file$DASH$REQUEST_ID$DASH$CURR_TIMESTAMP$DASH$TWO_TASK" ;
        echo "";
        echo "       Archive File Name:   $archive_file";
 
	if  [ -f $P_ARCHIVE_PATH/$archive_file ] ; 
        then
	    echo "WARNING: Archive file exists. Please move it manually.";
	else
			
			mv -f $P_DATA_FILE $archive_file

			case $? in
				 0) echo "";
					echo "       Data file moved To archive directory: $P_ARCHIVE_PATH";
					echo "       Data Archive file Name:               $archive_file";;
				 *) echo ""
					echo "       ERROR: Move to archive directory failed for Data File" ;
						archive_err=188;
					return $archive_err;;
			esac
	fi;
}
f_error ()
{
    err_code=$1
    echo " " 
	if [ $err_code -eq 0 ]
	then
				echo " " 
		     echo "  Common SQL Loader executed successfully" 
		     echo " " 
		     echo "           Data File Location : $P_DATA_LOC" 
		     echo "                    Data File : $P_DATA_FILE" 
		     echo "       Control File Location  : $P_CONTROL_LOC" 
		     echo "                Control File  : $P_CONTROL_FILE" 
		     echo "                 Archive Path : $P_ARCHIVE_PATH" 
	#	     echo "           Records Skip Count : $P_SKIP_CNT" 
		     echo "        Bad File and Location : $BAD_FILE" 
		     echo "    Discard File and Location : $DISCARD_FILE" 
		     echo " " 
		     echo " " 
		    # CURR_TIMESTAMP=`date +%Y%m%d%H%M` 
		    #echo "       Program Successfully Completed at:-  $CURR_TIMESTAMP" 
	             mv ${P_CONTROL_FILE}_bkp ${P_CONTROL_FILE}				####ADDED BY MISHU
		     exit 0
	fi


##################Changes done by Mishu ###########################################
#	To error the program if any record from flat file is invalid.
###################################################################################


	if [ $err_code -eq 177 ]
	then
		APPS_LOGIN=$SQL_USER
		     echo "$APPS_LOGIN
		     set serveroutput on

			     UPDATE XX_INV_TRANS_MISC 
			     SET STATUS = 'BATCH ERROR'
			     WHERE FILE_NAME = '$P_DATA_FILE_BKP';
			     COMMIT;
		     whenever sqlerror exit sqlcode
		exit" | sqlplus -s 

		mv ${P_CONTROL_FILE}_bkp ${P_CONTROL_FILE}
	     exit 1
	fi	

#
##################End Of changes done by Mishu #####################################

}


###-----------------------------------------------------------------------------------#
###-----------------------------------------------------------------------------------#
###-----------------------------------------------------------------------------------#
# Main Execution Program 
     echo "----------------------------------------------------------------------------"
     echo " --     Standard Interface SQL*Loader Shell script                    -" 
     echo "----------------------------------------------------------------------------"
     echo "" 
     echo "                    Start Date : `date`"
     echo ""
     echo "                 -------- Parameters ----------"
     echo ""
     echo "           Program Name: $PROGRAM_NAME" 
     echo "             Request ID: $REQUEST_ID" 
     echo "          Data File Loc: $P_DATA_FILE_LOC" 
     echo "         Data File Name: $P_DATA_FILE" 
     echo "      Control File Path: $P_CONTROL_LOC" 
     echo "      Control File Name: $P_CONTROL_FILE" 
     echo "      Archive Directory: $P_ARCHIVE_PATH" 
     echo ""
     echo "               Bad File: $BAD_FILE" 
     echo "           Discard File: $DISCARD_FILE" 
     echo "----------------------------------------------------------------------------"
     echo "----------------------------------------------------------------------------"

### -- Start of Main Processing 
# Validate Interface Home or Data Directory
     echo ""
     echo "STEP1: Validating Interface Home Data Directory"
     f_inf_dir $P_DATA_FILE_LOC
# Validate Data file 
     echo ""
     echo "STEP2: Validating Data File"
     f_data_file $P_DATA_FILE
############################################################
#Changes done by Javed to Insert the file name in the table
############################################################
     cp ${P_CONTROL_FILE} ${P_CONTROL_FILE}_bkp
     cat ${P_CONTROL_FILE} | sed "s/:FILE_NAME/$6/g" > ${P_CONTROL_FILE}_temp
     mv  ${P_CONTROL_FILE}_temp ${P_CONTROL_FILE} 
############################################################
# End of Changes by Javed
############################################################
#Validate Control file
     echo ""
     echo "STEP3: Validating SQL Loader Control file "
     f_ctl_file $P_CONTROL_FILE
# Execute SQL Loader

   
     echo ""
     echo "STEP4: Executing SQL Loader Procedure"
     f_call_sqlldr
############################################################
#Changes done by Javed to Insert the file name in the table
############################################################
     mv ${P_CONTROL_FILE}_bkp ${P_CONTROL_FILE}
############################################################
# End of Changes by Javed
############################################################

# Validate Archive directories
     echo ""
     echo "STEP5: Validating Interface Home Archive Directory"
     f_arc_dir $P_ARCHIVE_PATH
# Execute Archive Processing
     echo ""
     echo "STEP6: Executing Data Archiving Procedure "
     f_archive
