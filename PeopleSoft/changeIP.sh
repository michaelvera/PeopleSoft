#!/bin/sh
#
# Converts all pertinent PeopleSoft config files containing
#  an IP address with the new IP
#  when a PS_HOME is migrated to a new server
#
# Requires GNU sed with inline editing
#
# June2011 - Michael Vera

SED=/home/psoft/local/bin/sed

# Set old and new IP address
OLD='172.16.24.17'
NEW='172.16.6.12'

# Set required PS_HOME 
MY_PS_HOME="/hrtdm4/app/psoft/hr890"
cd $MY_PS_HOME

# File to be edited
FILES="
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/ps/webprof/config_prop
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/hrdv/webprof/config_prop
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/hrdm/webprof/config_prop
webserv/peoplesoft/servers/WebLogicAdmin/data/ldap/conf/replicas.prop
PSEMAgent/envmetadata/data/search-results.xml
"

# Replace old IP with new one, making a backup of the
#  file with the old server name as the extension
for file in $FILES
do
	$SED --in-place=".$OLD" "s/$OLD/$NEW/g" $file
        if [ $? -eq 0 ]; then
		echo "Updated $file successfully."
	else
		echo "Failed to update $file!"
		exit 1
	fi
done
