#!/bin/sh
#
# Converts all pertinent PeopleSoft config files server name
#  when a PS_HOME is migrated to a new server
#
# Requires GNU sed with inline editing
#
# 15Jun2011 - Michael Vera

SED=/home/psoft/local/bin/sed

# Set old and new server name
OLD="hpuch7"
NEW="col906"

# Set required PS_HOME 
MY_PS_HOME="/hrtdm4/app/psoft/hr890"
cd $MY_PS_HOME

# File to be edited
FILES="
appserv/prcs/hrdv/psprcsrv.env
appserv/prcs/hrdv/psprcsrv.ubb
appserv/prcs/hrdv/psprcs.cfg
appserv/prcs/hrdm/psprcsrv.env
appserv/prcs/hrdm/psprcsrv.ubb
appserv/prcs/hrdm/psprcs.cfg
appserv/prcs/psprcs.cfg
appserv/hrdv/psappsrv.ubb
appserv/hrdv/psappsrv.env
appserv/hrdv/psappsrv.cfg
appserv/hrdm/psappsrv.ubb
appserv/hrdm/psappsrv.env
appserv/hrdm/psappsrv.cfg
pscustom/sqr/scpfromproxy.pl
pscustom/sqr/scptoproxy.pl
webserv/peoplesoft/config/config.xml
webserv/peoplesoft/applications/HttpProxyServlet/WEB-INF/web.xml
webserv/peoplesoft/applications/HttpClusterServlet/WEB-INF/web.xml
webserv/peoplesoft/applications/peoplesoft/PSIGW/WEB-INF/integrationGateway.properties
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/weblogic.xml
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/ps/SyncServerGatewayConfig.xml
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/ps/webprof/config_prop
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/ps/configuration.properties
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/hrdv/SyncServerGatewayConfig.xml
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/hrdv/webprof/config_prop
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/hrdv/configuration.properties
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/hrdm/SyncServerGatewayConfig.xml
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/hrdm/webprof/config_prop
webserv/peoplesoft/applications/peoplesoft/PORTAL/WEB-INF/psftdocs/hrdm/configuration.properties
webserv/peoplesoft/applications/peoplesoft/pspc/wsdl/wsrp4j_service.wsdl
webserv/peoplesoft/applications/peoplesoft/pspc/WEB-INF/weblogic.xml
webserv/peoplesoft/applications/peoplesoft/pspc/WEB-INF/config/services/PIAService.properties
webserv/peoplesoft/applications/peoplesoft/pspc/WEB-INF/config/services/PIAService.properties
webserv/peoplesoft/applications/peoplesoft/pspc/WEB-INF/config/services/ConfigService.properties
webserv/peoplesoft/servers/domain_bak/config_prev/config.xml
webserv/peoplesoft/bin/setEnv.sh
PSEMAgent/envmetadata/config/configuration.properties
PSEMAgent/envmetadata/data/search-results.xml
PSEMAgent/envmetadata/data/emf_psae.sh
bea/tuxedo91/udataobj/webgui/webgui.ini
bea/registry.xml
ccr/hosts/hpuch7/config/default/targets.xml
ccr/hosts/hpuch7/config/emCCRenv
"

# Replace old server name with new one, making a backup of the
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
