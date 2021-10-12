###########################################################
# Fabien ROFFET : Auto Promote script
# 21.06.2021 - v1.0 : Creation
# 07.07.2021 - v1.1 : Use --csv
# 13.07.2021 - v1.2 : fix text, Filter default
# 29.09.2021 - v1.3 : Adding Cleaning paused tasks
# 10.11.2021 - v1.4 : Cleaning paused tasks - Fixed !
###########################################################

MDATE=`date +%B-%Y`
DESC="'Patching $MDATE'"
LOGS=./promote_content_last_version.log
MAILING="fabien.roffet@corp.cz"

if [ "$1" != "" ]; then
        echo "Organization :" $1
        ORGA=$1
else
        echo "Missing parameter :./promote_content_last_version.sh {ORG}"
        echo "List Oraganization :"
        hammer --csv --no-headers organization list --fields \"Name\"
        exit 0
fi


if [ "$2" != "" ]; then
        echo "Environement :" $2
        ENVI=$2
else
        echo "Missing parameter : ./promote_content_last_version.sh {ORG} {DEVT|PROD}"
        echo "List Lifecycle :"
        hammer --csv --no-headers lifecycle-environment list --fields "Name" | grep -v Library
        exit 0
fi

###########################################
# Redirection logs
###########################################
>$LOGS
exec > >(tee -i $LOGS)
exec 2>&1

###########################################
# Cleaning paused tasks
###########################################
echo "Cleaning paused tasks"

/sbin/foreman-rake foreman_tasks:cleanup TASK_SEARCH='label ~ *' STATES=paused VERBOSE=true

###########################################
# Check if there is not publish running
###########################################
echo " "
echo "Check if there is not publish running - Take time"
echo " "

while  [ "$(hammer --csv task list --search "Publish content view" --search "running" | grep -v "ID,Action")" != "" ]
        do
        echo "Publish content view still running"; sleep 30
done

echo "No Publish content view running"

###########################################
# Promoting to Prod or Devt
###########################################
COVI="hammer --csv --no-headers content-view list --fields \"Content View ID\" --organization $ORGA"
for IDCOVI in `eval $COVI`
        do
        LATEST_VERS=`hammer --csv --no-headers content-view version list --fields \"Version\" --content-view-id $IDCOVI  --organization $ORGA | head -n 1`

        echo hammer content-view version promote --description $DESC --version $LATEST_VERS --organization $ORGA --content-view-id $IDCOVI --to-lifecycle-environment $ENVI --force --async

        eval hammer content-view version promote --description $DESC --version $LATEST_VERS --organization $ORGA --content-view-id $IDCOVI --to-lifecycle-environment $ENVI --force --async
done

######################################################################################
# Send Email to the team
######################################################################################
mail -s "FOREMAN : promote_content_last_version.sh : DONE" $MAILING < $LOGS
