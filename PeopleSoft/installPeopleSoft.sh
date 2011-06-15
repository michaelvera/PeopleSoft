#!/bin/sh

#####################################################
# installPeopleSoft.sh
#
# 27May2011 - Michael Vera
#
# To install PeopleSoft 9.1 in an HP-UX environment
#  based on given user settings to automate the
#  installation for speed and disaster recovery 
#####################################################

#####################################################
### USER SETTINGS
#	These will be used as the environment variables
# 	for the application installation
#
HOME=/home/mvera # User's unix home directory
JAVA_HOME=/opt/java6
ORACLE_HOME=/hrpdm4/app/oracle/product/11202
TNS_ADMIN=/col906m1/app/oracle/admin
DBName=hrc2
ConnectId=people
ConnectPswd=people
PS_HOME=/hrupm4/app/psoft/pt851
MIDDLEWARE_HOME=$PS_HOME/middleware
WLS_INSTALL=/hrupm4/app/psoft/install
WLS_HOME=$MIDDLEWARE_HOME/wlserver_10.3
TMPDIR=/hrtdm4/tmp/installPeopleSoft
IATEMPDIR=/hrtdm4/tmp/installPeopleSoft
LOG=$TMPDIR/installPeopleSoft.log
TUXDIR=$MIDDLEWARE_HOME/tuxedo10gR3
TUX_INSTALL=/hrupm4/app/psoft/install
COB_ROOT=$PS_HOME/microfocus
COBDIR=$COB_ROOT/svrexp-51_wp4-64bit
COB_INSTALL=/hrupm4/app/psoft/install
PS_INSTALL=/hrupm4/app/psoft/install
VERITY_INSTALL=/hrupm4/app/psoft/install
#
### END USER SETTINGS
#####################################################

export JAVA_HOME ORACLE_HOME TNS_ADMIN PS_HOME MIDDLEWARE_HOME
export WLS_INSTALL WLS_HOME TUXDIR TUX_INSTALL IATEMPDIR PS_INSTALL

### Reset the install log with the current date/tmie
date > $LOG|| ( echo "\aCan't open log file $LOG, exiting!"; exit 1 )

####################################################
### Test UNIX Environment
### Change to /tmp to protect filesystems from who knows what
cd /tmp || ( echo "No /tmp mount point? Exiting."; exit 1)

if [ ! -d $TMPDIR ]
then
	mkdir $TMPDIR || ( echo "Cant create $TMPDIR! Exiting!"; exit 1 )
fi

touch $TMPDIR/delete.me.now
RESULT=$?
if [ $RESULT != 0 ]
then
	echo "Cant write to $TMPDIR! Exiting!"
	exit 1
fi
rm $TMPDIR/delete.me.now|| ( echo "Couldnt find delete.me.now." >> $LOG )

### Now change to $TMPDIR to work
cd $TMPDIR

### $STATUS Shows the last successfully installed task
#    each echo to STATUS should overwrite the last
STATUS=$TMPDIR/installPeopleSoft.status
echo "LAST SUCCESSFUL STEP: $TMPDIR found and writable" > $STATUS
echo "You can check the last successful step of the installation in $STATUS"
echo "Use this command to view:\n\tcat $STATUS\a"

### Test Cobol environment
#
if [ ! -d $COB_ROOT ]
then
	mkdir $COB_ROOT >> $LOG 2>&1 || ( echo "Cant create Cobol root directory $COB_ROOT, exiting!"; exit 3 )
else
	echo "$COB_ROOT exists" >> $LOG
fi
if [ ! -d $COBDIR ]
then
	mkdir $COBDIR >> $LOG 2>&1 || ( echo "Cant create Cobol directory $COBDIR, exiting!"; exit 3 )
else
	echo "$COBDIR exists" >> $LOG
fi

touch $COBDIR/delete.me.now >> $LOG 2>&1
RESULT=$?
if [ $RESULT -gt 0 ]
then
	echo "Can't create a file in $COBDIR! Check ownership and permissions. Exiting!"
	exit 1
fi
echo "Cobol installation path ready." >> $LOG


## Add more directory tests here
#

echo "LAST SUCCESSFUL STEP: UNIX Environment Ready" > $STATUS
echo "UNIX Environment Ready" >> $LOG
echo "UNIX Environment Ready"
#
### End of UNIX environment tests
####################################################

date >> $LOG

####################################################
### 1-13 Test Oracle connectivity
# 
# Test ORACLE_HOME
echo "Testing Oracle Database connectivity."
if [ ! -d $ORACLE_HOME ]
then
	echo "\aORACLE_HOME does not exist! Exiting!"
	exit 2
fi

echo "LAST SUCCESSFUL STEP: ORACLE_HOME exists" > $STATUS

if [ ! -x $ORACLE_HOME/bin/sqlplus ]
then
	echo "\aSQLPlus not installed! Exiting"
	exit 2
fi

echo "LAST SUCCESSFUL STEP: SQLPLUS exists as an executable" > $STATUS

# Create test sql file in tmp space
echo "select * from all_users;\nexit;" > $TMPDIR/testDB.sql

# Connect to database
$ORACLE_HOME/bin/sqlplus $ConnectId/$ConnectPswd@$DBName @$TMPDIR/testDB.sql >> $LOG 2>&1
RESULT=$?
if [ $RESULT != 0 ]
then
	echo "\aConnection error in SQLPLUS! Exiting!"
	exit 2
fi
echo "LAST SUCCESSFUL STEP: Database Connection good!" > $STATUS
echo "Database Connection good!\n" >> $LOG
echo "Database Connection good!\n"
rm $TMPDIR/testDB.sql||echo "Can't remove $TMPDIR/testDB.sql!" >> $LOG
#
### End Task 1-13
####################################################

date >> $LOG

####################################################
### Task 2-1 WEBLOGIC INSTALL
#	WebLogic Server 11gR1 (10.3.3) Generic
echo "Installing WebLogic Server 10.3.3 Generic."

### Check for the zipped e-delivery file for Weblogic
#	V21016-01.zip
if [ ! -f $WLS_INSTALL/V21016-01.zip ]
then
	echo "$WLS_INSTALL/V21016-01.zip not found! Exiting!"
	exit 3
fi

echo "LAST SUCCESSFUL STEP: E-Delivery WebLogic install zip file, $WLS_INSTALL/V21016-01.zip, found" > $STATUS

### Unzip WLS install file
#
if [ -f $WLS_INSTALL/wls1033_generic.jar ]
then
	echo "WebLogic installation file has already been unzipped in $WLS_HOME." >> $LOG
else
	echo "Unzipping Weblogic installation file..\c"
	unzip -o $WLS_INSTALL/V21016-01.zip -d $WLS_INSTALL >> $LOG 2>$1
	RESULT=$?
	if [ $RESULT != 0 ]
	then
		echo "\aProblem unzipping $WLS_INSTALL/V21016-01.zip! Exiting!"
		exit 3
	fi
	echo ".done."
fi
rm $WLS_INSTALL/README.txt >> $LOG 2>&1 || ( echo "Cant find $WLS_INSTALL/README.txt." >> $LOG )
echo "LAST SUCCESSFUL STEP: Unzipped Welogic install file into $WLS_INSTALL" > $STATUS

### Task 2-1-5 Install Weblogic in Silent mode
### Create XML doc to tell WebLogic where it can go.
cat > $WLS_INSTALL/installer.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<domain-template-descriptor>
<input-fields>
  <data-value name="BEAHOME" value="$MIDDLEWARE_HOME" />
  <data-value name="WLS_INSTALL_DIR" value="$WLS_HOME" />
  <data-value name="COMPONENT_PATHS" value="WebLogic Server/Core \
Application Server|WebLogic Server/Administration Console|WebLogic \
Server/Configuration Wizard and Upgrade Framework|WebLogic \
Server/Web 2.0 HTTP Pub-Sub Server|WebLogic Server/WebLogic \
JDBC Drivers|WebLogic Server/Third Party JDBC Drivers|WebLogic \
Server/WebLogic Server Clients|WebLogic Server/WebLogic Web \
Server Plugins|WebLogic Server/UDDI and Xquery Support|WebLogic \
Server/Workshop Code Completion Support" />
 <data-value name="INSTALL_NODE_MANAGER_SERVICE" value="no" />
</input-fields>
</domain-template-descriptor>
EOF

echo "Check WebLogic silent installation details at $WLS_INSTALL/installer.xml" >> $LOG
echo "LAST SUCCESSFUL STEP: Created XML silent installation config file in $WLS_INSTALL/installer.xml" > $STATUS

### Run WebLogic installer in solent mode
echo "Starting WebLogic silent installation..\c"

### nohup $JAVA_HOME/bin/java -d64 -jar $WLS_INSTALL/wls1033_generic.jar -mode=silent -silent_xml=$WLS_INSTALL/installer.xml -log=$LOG.wls_install >> $LOG 2>&1

echo "\acompleted."

### Check for successfull WebLogic installation
grep "The installation was successful" $LOG.wls_install >> $LOG 2>&1
RESULT=$?
if [ $RESULT -gt 0 ]
then
	echo "WebLogic installation failed! Check $LOG & $LOG.wls_install"
	exit 3
else
	# Installation should be at least 1351630 blocks to be "good"
	WLS_SIZE=`du -s $WLS_HOME|cut -f1`
	if [ $WLS_SIZE -ge 1351000 ]
	then
		echo "WebLogic installation successfull!"
		echo "LAST SUCCESSFUL STEP: Installed WebLogic into $WLS_HOME" > $STATUS
	else
		echo "WebLogic installation seems too small! Perhaps the installation failed? Check $LOG & $LOG.wls_install"
		exit 3
	fi
fi
### End of WebLogic Install
####################################################

date >> $LOG

####################################################
### TASK 3-1: Installing Oracle Tuxedo
#
# e-Delivery file: V15059-01.zip
# Tuxedo 10gR3 for HP-UX Itanium (64-bit)

### Check for the zipped e-delivery file for Tuxedo
#       V15059-01.zip
if [ ! -f $TUX_INSTALL/V15059-01.zip ]
then
	echo "$TUX_INSTALL/V15059-01.zip not found! Exiting!"
	exit 3
fi

echo "LAST SUCCESSFUL STEP: E-Delivery Tuxedo install zip file, $TUX_INSTALL/V15059-01.zip, found" > $STATUS

### Unzip TUX install file
#
if [ -f $TUX_INSTALL/tuxedo10gR3_64_hpux_1123_ia.bin ]
then
	echo "Tuxedo installation file has already been unzipped in $TUX_INSTALL" >> $LOG
else
	echo "Unzipping Tuxedo installation file..\c"
	unzip -c $TUX_INSTALL/V15059-01.zip -d $WLS_INSTALL >> $LOG 2>&1
	RESULT=$?
	if [ $RESULT != 0 ]
	then
		echo "\aProblem unzipping $TUX_INSTALL/V15059-01.zip! Exiting!"
		exit 4
	else
		chmod +x $TUX_INSTALL/tuxedo10gR3_64_hpux_1123_ia.bin >> $LOG 2>&1 || ( echo "Problem setting permissions on Tuxedo installation binary file $TUX_INSTALL/tuxedo10gR3_64_hpux_1123_ia.bin! Exiting!"; exit 4 )
	fi
	echo ".done."
fi
echo "LAST SUCCESSFUL STEP: Tuxedo installation file unzipped and ready to execute" > $STATUS

### Create Tuxedo silent installation configuration file
cat > $TUX_INSTALL/installer.properties <<EOF
### Tuxedo Silent Install Configuration File
### Created by installPeopleSoft.sh
INSTALLER_UI=silent
USER_LOCALE=en
INSTALL_MODE=New Install
ORACLEHOME=$ORACLE_HOME
USER_INSTALL_DIR=$TUXDIR
### LDAP ###
#LDAP_HOSTNAME=col007.col.lakelandgov.lcl
#LDAP_PORTID=389
#LDAP_BASE_OBJECT="dc=col,dc=lakelandgov,dc=lcl"
#LDAP_FILTER_FILE=$TUXDIR/udataobj/security/bea_ldap_filter.dat
TLISTEN_PASSWORD=password
CHOSEN_INSTALL_SET=Full Install
INSTALL_SAMPLES=Yes

EOF

echo "LAST SUCCESSFUL STEP: Tuxedo silent installation configuration file created: $TUX_INSTALL/installer.properties " > $STATUS

echo "Installing Tuxedo..\c"

###$TUX_INSTALL/tuxedo10gR3_64_hpux_1123_ia.bin -i silent -f $TUX_INSTALL/installer.properties

echo ".done"

### End TASK 3-1: Installing Oracle Tuxedo
####################################################

date >> $LOG
echo "LAST SUCCESSFUL STEP: Tuxedo installed!" > $STATUS
echo "LAST SUCCESSFUL STEP: Tuxedo installed!" >> $LOG

####################################################
### Task 3-3 Install Microfocus Cobol
### E-Delivery file: V21679-01.zip
### Installed in $COBDIR
if [ ! -f $COB_INSTALL/V21679-01.zip ]
then
	echo "Cobol installation file, $COB_INSTALL/V21679-01.zip not found! Exiting!"
	exit 3
else
	echo "Cobol installation file found: $COB_INSTALL/V21679-01.zip"
fi 

if [ ! -f $COB_INSTALL/sx51_wp4_hp_itanium_dev.tar ]
then
	echo "Unzipping Cobol installation file." >> $LOG
	unzip -o $COB_INSTALL/V21679-01.zip -d $COB_INSTALL >> $LOG 2>&1
	RESULT=$?
	if [ $RESULT -gt 0 ]
	then
		echo "Failed to unzip Cobol installation file! Command used follows:\n\tunzip -o $COB_INSTALL/V21679-01.zip -d $COB_INSTALL >> $LOG 2>&1"
		exit 3
	else
		echo "Cobol installation file unzipped to $COB_INSTALL!" >> $LOG
	fi

fi

### Untar the installation to the correct location
mkdir $COB_INSTALL/svrexp-51_wp4-64bit
tar -xf $COB_INSTALL/sx51_wp4_hp_itanium_dev.tar -C $COB_INSTALL/svrexp-51_wp4-64bit >> $LOG 2>&1
RESULT=$?
if [ $RESULT -gt 0 ]
then
	echo "Tar command for Cobol installation failed! Exiting!" 
	exit 3
fi

echo "LAST SUCCESSFUL STEP: Cobol installation file unzipped into $COB_INSTALL" > $STATUS

### Run installer


### END Task 3-3 Install Microfocus Cobol
####################################################

date >> $LOG

####################################################
### Task 4-3 Install PeopleTools  8.51
### Requires e-Delivery files:
###	V22547-01.zip
###	V22548-01.zip
###	V22549-01.zip

### Check for the zipped e-delivery file for PeopleTools
# V22547-01.zip V22548-01.zip V22549-01.zip
if [ ! -f $PS_INSTALL/V22547-01.zip ] || [ ! -f $PS_INSTALL/V22548-01.zip ] || [ ! -f $PS_INSTALL/V22548-01.zip ]
then
	echo "Installation files not found in $PS_INSTALL! Exiting!"
	echo "Make sure all three installation files are in $PS_INSTALL!" >> $LOG
	echo "	V22547-01.zip V22548-01.zip V22549-01.zip" >> $LOG
	exit 5
fi

echo "LAST SUCCESSFUL STEP: Found PeopleTools 8.51 installation files in $PS_INSTALL" > $STATUS

echo "Preparing PeopleTools 8.51 installation folders." >> $LOG
echo "Preparing PeopleTools 8.51 installation folders..\c"

### Unzip PT851 install files
#
if [ ! -d $PS_INSTALL/Disk1 ]
then
	echo "Unzipping PeopleTools installation Disk1." >> $LOG
	unzip -o $PS_INSTALL/V22547-01.zip -d $PS_INSTALL >> $LOG 2>&1
else
	echo "PeopleTools 8.51 installation directory Disk1 found." >> $LOG
	echo "Checking Disk1 directory size" >> $LOG
	DISK1_SIZE=`du -s $PS_INSTALL/Disk1|cut -f1`
	if [ $DISK1_SIZE -ge 2681000 ]
	then
		echo "PeopleTools Disk1 found and appears to be ready to use." >> $LOG
	else
		echo "Unzipping PeopleTools installation Disk1 to overwrite existing Disk1." >> $LOG
		unzip -o $PS_INSTALL/V22547-01.zip -d $PS_INSTALL >> $LOG 2>&1
	fi
fi

### Make setup.sh executable
echo "Making $PS_INSTALL/Disk1/setup.sh executable." >> $LOG
chmod +x $PS_INSTALL/Disk1/setup.sh >> $LOG 2>&1|| ( echo "Can't change permissions on $PS_INSTALL/Disk1/setup.sh! something is very wrong! Exiting."; exit 5 )
chmod +x $PS_INSTALL/Disk1/InstData/setup.* >> $LOG 2>&1|| ( echo "Can't change permissions on $PS_INSTALL/Disk1/InstData/setup.*! something is very wrong! Exiting."; exit 5 )

echo "LAST SUCCESSFUL STEP: E-Delivery PeopleTools 8.51 Installation Disk1 ready in $PS_INSTALL" > $STATUS


if [ ! -d $PS_INSTALL/Disk2 ]
then
	echo "Unzipping PeopleTools installation Disk2." >> $LOG
	unzip -o $PS_INSTALL/V22548-01.zip -d $PS_INSTALL >> $LOG 2>&1
else
	echo "PeopleTools 8.51 installation directory Disk2 found." >> $LOG
	echo "Checking Disk2 directory size" >> $LOG
	DISK2_SIZE=`du -s $PS_INSTALL/Disk2|cut -f1`
	if [ $DISK2_SIZE -ge 3904000 ]
	then
		echo "PeopleTools Disk2 found and appears to be ready to use." >> $LOG
	else
		echo "Unzipping PeopleTools installation Disk2 to overwrite existing Disk2." >> $LOG
		unzip -o $PS_INSTALL/V22548-01.zip -d $PS_INSTALL >> $LOG 2>&1
	fi
fi

echo "LAST SUCCESSFUL STEP: E-Delivery PeopleTools 8.51 Installation Disk2 ready in $PS_INSTALL" > $STATUS

if [ ! -d $PS_INSTALL/Disk3 ]
then
	echo "Unzipping PeopleTools installation Disk3." >> $LOG
	unzip -o $PS_INSTALL/V22549-01.zip -d $PS_INSTALL >> $LOG 2>&1
else
	echo "PeopleTools 8.51 installation directory Disk3 found." >> $LOG
	echo "Checking Disk3 directory size" >> $LOG
	DISK3_SIZE=`du -s $PS_INSTALL/Disk3|cut -f1`
	if [ $DISK3_SIZE -ge 1107000 ]
	then
		echo "PeopleTools Disk3 found and appears to be ready to use." >> $LOG
	else
		echo "Unzipping PeopleTools installation Disk3 to overwrite existing Disk3." >> $LOG
		unzip -o $PS_INSTALL/V22549-01.zip -d $PS_INSTALL >> $LOG 2>&1
	fi
fi

echo ".done."

echo "LAST SUCCESSFUL STEP: E-Delivery PeopleTools 8.51 Installation Disk3 ready in $PS_INSTALL" > $STATUS

date >> $LOG
echo "PeopleTools installation files are ready!" >> $LOG

echo "PeopleTools installation files are ready!"

### Install PeopleTools
echo "$PS_INSTALL/Disk1/setup.sh -tempdir $IATEMPDIR -javahome $JAVA_HOME"

### END Task 4-3 Install PeopleTools
####################################################

echo "LAST SUCCESSFUL STEP: PeopleTools 8.51 Installed in $PS_HOME" > $STATUS

####################################################
### Task 4-4-2 Verity integration Kit
### E-Delivery file: V22550-01.zip
if [ ! -d $VERITY_INSTALL/Verity/Disk1 ]
then
	echo "Unzipping Verity installation Disk1." >> $LOG
	unzip -o $VERITY_INSTALL/V22550-01.zip -d $VERITY_INSTALL >> $LOG 2>&1
else
	echo "Verity installation directory Disk1 found: $VERITY_INSTALL/Verity/Disk1" >> $LOG 2>&1
	echo "Checking Verity install directory size." >> $LOG
	VERITY_SIZE=`du -s $VERITY_INSTALL/Verity/Disk1|cut -f1 >> $LOG 2>&1`
	if [ $VERITY_SIZE -ge 2561000 ]
	then
		echo "Verity installation directory appears to be ready to use." >> $LOG
	else
		echo "Unzipping Verity installation to overwrite existing Disk1" >> $LOG
		unzip -o $VERITY_INSTALL/V22550-01.zip -d $VERITY_INSTALL >> $LOG 2>&1
	fi
fi

### Make setup files executable
echo "Making Verity installation files executable in $VERITY_INSTALL/Verity/Disk1." >> $LOG
chmod +x $VERITY_INSTALL/Verity/Disk1/setup.sh >> $LOG 2>&1||( echo "Can't change permissions on $VERITY_INSTALL/Disk1/setup.sh! something is very wrong! Exiting."; exit 6 )
chmod +x $VERITY_INSTALL/Verity/Disk1/InstData/setup.* >> $LOG 2>&1||( echo "Can't change permissions on $VERITY_INSTALL/Disk1/InstData/setup.*! something is very wrong! Exiting."; exit 6 )

echo "Verity files ready for installation!" >> $LOG
echo "LAST SUCCESSFUL STEP: Verity Integration Kit unzipped and ready to use." > $STATUS

$VERITY_INSTALL/Verity/Disk1/setup.sh -tempdir $IATEMPDIR

### End Task 4-4-2 Verity integration Kit
####################################################

date >> $LOG

####################################################
### Patch the PeopleTools installation
### E-Delivery file: 85106.zip
### unzip -P "Interest1ng\$Contender" 85106.zip
### ./Disk1/setup.sh -tempdir $IATEMPDIR
####################################################


####################################################
### Cleanup after script

rm -fr $HOME/bea
rm -fr $HOME/oradiag_mvera
rm -fr $HOME/install.dir.*

echo "Bye." >> $LOG
date >> $LOG
