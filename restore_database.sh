#!/bin/bash 

###################################################################################################################################
#
# Script......: restore_database.sh
# Readme......: Restore backup image creating redirect archive and changing tablespaces directory.
#       	restore_database.sh <<SOURCE_DATABASE_ALIAS>> <<TARGET_DATABASE_ALIAS>> <<TARGET_DIRECTORY_TO>>
#		./restore_database.sh CISSERP TESTE /db2/backup
#
# Author......: Douglas Jose Dambros << douglas.dambros@ciss.com.br / douglasjosedambros@gmail.com >> 
# Create date.: 09/03/2022
# Last change.: 22/03/2022
# Version.....: 0.1 (Creating)
#
###################################################################################################################################


## Variables
#SOURCE_DATABASE_ALIAS="$1"
#TARGET_DATABASE_ALIAS="$2"
#TARGET_DIRECTORY="$3"

## Styles
bold=$(tput bold)
underline=$(tput smul)
italic=$(tput sitm)
info=$(tput setaf 2)
error=$(tput setaf 160)
warn=$(tput setaf 214)
reset=$(tput sgr0)

## Variables test with offline backup
#SOURCE_DATABASE_ALIAS="CISSERP"
#TARGET_DATABASE_ALIAS="DOUG"
#TARGET_DIRECTORY="/db2/DATABASES"

## Variables test with online backup
#SOURCE_DATABASE_ALIAS="JPGT"
#TARGET_DATABASE_ALIAS="DOUG"
#TARGET_DIRECTORY="/db2/DATABASES"

## Variables teste with TESTE database
SOURCE_DATABASE_ALIAS="CISSERP"
TARGET_DATABASE_ALIAS="TESTE"
TARGET_DIRECTORY="/db2/backup"

## Functions
showUsage()
{
	echo ""
	echo -e "${error}Invalid parameter.${reset}"
	echo ""
	echo "Usage: ./restore_database.sh SOURCE_DATABASE_ALIAS TARGET_DATABASE_ALIAS TARGET_DIRECTORY_TO"
	echo ""
	echo "SOURCE_DATABASE_ALIAS  Alias of the source database from which the backup was taken."
	echo "TARGET_DATABASE_ALIAS  The target database alias."
	echo "TARGET_DIRECTORY       This parameter states the target database directory."
	echo ""
	echo ""
	echo "Exiting now!!!"
	echo ""
	return
}


getMemory()
{
	local MEMORY_TOTAL=`free -m | grep "Mem:" | awk {'print $2'}`
	local MEMORY_FREE=`free -m | grep "Mem:" | awk {'print $4'}`
	echo 	" | [Memory]"
	echo 	" |"
	echo -e " | Total: \t\t\t${MEMORY_TOTAL} MB"
	echo -e " | Free: \t\t\t${MEMORY_FREE} MB"
	echo 	""
}

getDB2Version()
{
	local 	PRODUCT_IDENTIFIER=`db2licm -l | grep "Product identifier:" | awk {'print $3'} | head -n1 | sed s/\"//g`
	local 	PRODUCT_NAME=`db2licm -l | grep "Product name:" | awk {'print $3,$4'} | head -n1 | sed s/\"//g`
		PRODUCT_VERSION=`db2level | grep "Informational" | awk {'print $5'} | head -n1 | sed s/\",//g`
	echo 	" | [DB2]"
	echo 	" |"
	echo -e " | Product name: \t\t${PRODUCT_NAME}"
	echo -e " | Product identifier: \t\t${PRODUCT_IDENTIFIER}"
	echo -e " | Product version: \t\t${PRODUCT_VERSION}"
	echo 	""
}

getInstance()
{
	INSTANCE_NAME=`db2level | grep "DB2 code release" | awk {'print $1'} | sed s/\)//g | sed s/\"//g`
	local INSTANCE_MEMORY=`db2 get dbm cfg | grep "INSTANCE_MEMORY" | cut -d"=" -f 2 | sed s/\ //g`
        echo 	" | [Instance]"
        echo 	" |"
	echo -e " | Instance name: \t\t${INSTANCE_NAME}"
        echo -e " | Global memory (% or 4KB): \t${INSTANCE_MEMORY}"
        echo 	""	
}

getDatabases()
{
	# Get instance databases
	declare DATABASES=(`db2 list db directory | grep alias | awk {'print $4'}`)
	TARGET_DATABASE_ALIAS_UPPER=`echo ${TARGET_DATABASE_ALIAS} | tr a-z A-Z`

	echo	" | [Instance databases]"
	echo	" |"
	echo -e " | Databases: \t\t\t${DATABASES[*]}"

	# Target database alias already exists
	for d in "${DATABASES[@]}"
	do	
		if [ $d == ${TARGET_DATABASE_ALIAS_UPPER} ];
		then
			echo -e "\n${error}Target database alias \"${TARGET_DATABASE_ALIAS_UPPER}\" already exists in instance ${INSTANCE_NAME} \n\nAbort\n${reset}"
			
			exit 1
		fi
	done
}


# Valid empty parameters
if [ "${SOURCE_DATABASE_ALIAS}" == "" ] || [ "${TARGET_DATABASE_ALIAS}" == "" ] || [ "${TARGET_DIRECTORY}" == "" ]
then
        showUsage
        exit 1
fi

# Invalid target database alias length
if  [ ${#TARGET_DATABASE_ALIAS} -ge 9 ]
then
	echo -e "${error}Database alias length more than eight\n\nAbort\n${reset}"
	exit 1
fi

# Start
echo ""
echo ""
echo "${bold}Start${reset}"
echo ""
echo "With user $(whoami) at $(date)"



echo ""
echo ""
echo "${bold}Step - Checking enviroment${reset}"
echo ""

# Get, check and print info
getMemory
getDB2Version
getInstance
getDatabases


echo ""
echo ""
echo "${bold}Step - Checking backup${reset}"
echo ""

# Get backup image name
BACKUP_IMAGE=`ls ${SOURCE_DATABASE_ALIAS}.*`

# Generate check backup log
echo -e "--> db2ckbkp -h ${BACKUP_IMAGE} > db2ckbkp_${SOURCE_DATABASE_ALIAS}.txt"
db2ckbkp -h ${BACKUP_IMAGE} > db2ckbkp_${SOURCE_DATABASE_ALIAS}.txt

# Get variables from check backup log
BACKUP_MODE=`cat db2ckbkp_${SOURCE_DATABASE_ALIAS}.txt | grep 'Backup Mode' | awk '{print $5}' | sed s/\(//g | sed s/\)//g`
BACKUP_RELEASE_ID=`cat db2ckbkp_${SOURCE_DATABASE_ALIAS}.txt | grep 'Release ID' | awk '{print $6}' | sed s/\)//g`

echo 	""
echo -e " | Backup Mode: \t\t${BACKUP_MODE}"
echo -e " | Release ID: \t\t\t${BACKUP_RELEASE_ID}"

# Different instance and backup version
if [ ${BACKUP_RELEASE_ID} != ${PRODUCT_VERSION} ] 
then
        echo -e "${error}Different instance and backup version\n\nAbort\n${reset}"
        exit 1
fi



echo ""
echo ""
echo "${bold}Step - Creating directories${reset}"
echo ""

# Check if database directory already exists
if [ -d "${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}" ]
then

	echo -e "Directory ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS} already exists.\n"

		while true; do
		    read -p "Do you wish to continue? (yes/no):" yn
		    case $yn in
		        [Yy]* ) break;;
		        [Nn]* ) exit;;
		        * ) echo "Please answer yes or no.";;
		    esac
		done
fi

echo ""

# Check if log extract directory already exists and is empty
if [ -n "$(ls -A ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT/)" ]
then

	echo -e "There are some files in ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT/\n"
	
		while true; do
	            read -p "Do you wish remove and continue? (yes/no):" yn
	            case $yn in
	                [Yy]* ) break;;
	                [Nn]* ) exit;;
	                * ) echo "Please answer yes or no.";;
	            esac
	        done
	
	echo ""
	echo -e "--> rm -r ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT/*"
	rm -r ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT/*

fi

echo -e "--> mkdir -p ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_ROTATE"
mkdir -p ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_ROTATE
echo -e "--> mkdir -p ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_ARCHIVE"
mkdir -p ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_ARCHIVE 
echo -e "--> mkdir -p ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT"
mkdir -p ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT 



echo ""
echo ""
echo -e "${bold}Step - Restoring database ${SOURCE_DATABASE_ALIAS} as ${TARGET_DATABASE_ALIAS}${reset}"
echo ""

if [ "${BACKUP_MODE}" == "Offline" ]
then
        echo -e "--> db2 \"RESTORE DB ${SOURCE_DATABASE_ALIAS} DBPATH ON ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS} INTO ${TARGET_DATABASE_ALIAS} REDIRECT GENERATE SCRIPT REDIRECT.CLT\""
	db2 "RESTORE DB ${SOURCE_DATABASE_ALIAS} DBPATH ON ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS} INTO ${TARGET_DATABASE_ALIAS} REDIRECT GENERATE SCRIPT REDIRECT.CLT"
else
	echo -e "--> db2 \"RESTORE DB ${SOURCE_DATABASE_ALIAS} DBPATH ON ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS} INTO ${TARGET_DATABASE_ALIAS} LOGTARGET ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT REDIRECT GENERATE SCRIPT REDIRECT.CLT\""
	db2 "RESTORE DB ${SOURCE_DATABASE_ALIAS} DBPATH ON ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS} INTO ${TARGET_DATABASE_ALIAS} LOGTARGET ${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT REDIRECT GENERATE SCRIPT REDIRECT.CLT"
fi



echo ""
echo ""
echo "${bold}Step 3 Editing REDIRECT.CLT${reset}"
echo ""

#Get NEWLOGPATH
echo -e "--> cat REDIRECT.CLT | grep -oP '(?<=NEWLOGPATH ).*(?=${SOURCE_DATABASE_ALIAS})' | sed s/\'//g"
CMD="cat REDIRECT.CLT | grep -o -P '(?<=NEWLOGPATH ).*(?=${SOURCE_DATABASE_ALIAS})' | sed s/\'//g"
NEWLOGPATH_DIRECTORY=$(eval "$CMD")

echo -e "--> grep -n \"NEWLOGPATH\" REDIRECT.CLT | cut -d : -f1"
NEWLOGPATH_LINE=`grep -n "NEWLOGPATH" REDIRECT.CLT | cut -d : -f1`


# Alter NEWLOGPATH
# Remove NEWLOGPATH line
echo -e "--> sed -i \"${NEWLOGPATH_LINE}d\" REDIRECT.CLT"
sed -i "${NEWLOGPATH_LINE}d" REDIRECT.CLT

# Add new NEWLOGPATH line
echo -e "--> sed -i \"${NEWLOGPATH_LINE}i NEWLOGPATH '${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_ROTATE/'\" REDIRECT.CLT"
sed -i "${NEWLOGPATH_LINE}i NEWLOGPATH '${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_ROTATE/'" REDIRECT.CLT

# Replace / for \/
NEWLOGPATH_DIRECTORY_AUX="${NEWLOGPATH_DIRECTORY////\/}"
TARGET_DIRECTORY_AUX="${TARGET_DIRECTORY////\/}"

# Alter tablespaces
echo -e "--> sed -i 's/${NEWLOGPATH_DIRECTORY_AUX}${SOURCE_DATABASE_ALIAS}/${TARGET_DIRECTORY_AUX}\/${TARGET_DATABASE_ALIAS}/g' REDIRECT.CLT"
TESTE="sed -i 's/${NEWLOGPATH_DIRECTORY_AUX}${SOURCE_DATABASE_ALIAS}/${TARGET_DIRECTORY_AUX}\/${TARGET_DATABASE_ALIAS}/g' REDIRECT.CLT"
eval "$TESTE"



echo ""
echo ""
echo "${bold}Step - Restore database${reset}"
echo ""

# tvf (restore)
echo -e "--> db2 -tvf REDIRECT.CLT"
db2 -tvf REDIRECT.CLT

# Update log archive
echo -e "--> db2 \"update db cfg for ${TARGET_DATABASE_ALIAS} using logarchmeth1 disk:${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_ARCHIVE\""
db2 "update db cfg for ${TARGET_DATABASE_ALIAS} using logarchmeth1 disk:${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_ARCHIVE"
echo ""

# Rollforward
if [ "${BACKUP_MODE}" == "Offline" ]
then
	echo -e "--> db2 \"ROLLFORWARD DB ${TARGET_DATABASE_ALIAS} STOP\""
	db2 "ROLLFORWARD DB ${TARGET_DATABASE_ALIAS} STOP"
else
	echo -e "--> db2 \"ROLLFORWARD DB ${TARGET_DATABASE_ALIAS} TO END OF LOGS AND COMPLETE OVERFLOW LOG PATH(${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT)\""
        db2 "ROLLFORWARD DB ${TARGET_DATABASE_ALIAS} TO END OF LOGS AND COMPLETE OVERFLOW LOG PATH(${TARGET_DIRECTORY}/${TARGET_DATABASE_ALIAS}/LOGS/LOG_EXTRACT)"
fi

echo ""


# Test connection
echo -e "--> db2 connect to ${TARGET_DATABASE_ALIAS}"
db2 connect to ${TARGET_DATABASE_ALIAS}
echo ""


exit 0



#################################################################################################################################
#
#	..:: Improvements to do ::..
#
# - [Step - Checking backup] When capture backup image full name, check if exists only one image backup witch that name
# - [Step - Checking backup] Error while analyse image backup
# - [Step - Checking backup] Get tablespace names from db2ckbkp analysis
# - [Step - Checking backup] Get database size from db2ckbkp analysis
# - Check memory and disk available
# - Error handling
# - Execute updv if necessary
# - Alter session "Get NEWLOGPATH" because in different databases it wont work fine
#
#################################################################################################################################
