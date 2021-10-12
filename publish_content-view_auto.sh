###########################################################
# Fabien ROFFET : Auto Publish script
# 21.06.2021 - v1.0 : Creation
# 07.07.2021 - v1.1 : Auto Description, split cv and ccv
# 13.07.2021 - v1.2 : Fix Text
# 20.07.2021 - v1.3 : Adding --nondefault=yes
# 29.09.2021 - v1.4 : Adding Cleaning paused tasks
###########################################################

MDATE=`date +%B-%Y`
DESC="'Patching $MDATE'"
LOGS=./publish_content-view_auto.log
MAILING="fabien.roffet@corp.cz"

if [ "$1" != "" ]; then
        echo "Organization :" $1
        ORGA=$1
else
        echo "Missing parameter :./publish_content-view_auto.sh {ORG}"
        echo "List Oraganization :"
        hammer --csv --no-headers organization list --fields \"Name\"
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
echo " "
echo "Cleaning paused tasks"
echo " "

/sbin/foreman-rake foreman_tasks:cleanup TASK_SEARCH='label ~ *' STATES=paused VERBOSE=true

######################################################################################
# First Publish Content-View - Checking if the filed Composite is true / false
######################################################################################
echo " "
echo "Publish Content-View"
echo " "

COVI="hammer --csv --no-headers content-view list --nondefault=yes --fields \"Content View ID\",\"Composite\" --organization $ORGA"
for IDCOVI in `eval $COVI | grep false | cut -d"," -f1`
        do
                echo hammer  content-view  publish --async --id $IDCOVI --organization $ORGA --description $DESC
                eval hammer  content-view  publish --async --id $IDCOVI --organization $ORGA --description $DESC
done

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

######################################################################################
# Now only COMPOSITE Content-View - Checking if the filed Composite is true / false
######################################################################################
echo " "
echo "Publish Composite Content-View"
echo " "

COVI="hammer --csv --no-headers content-view list --nondefault=yes --fields \"Content View ID\",\"Composite\" --organization $ORGA"
for IDCOVI in `eval $COVI | grep true | cut -d"," -f1`
        do
                echo hammer  content-view  publish --async --id $IDCOVI --organization $ORGA --description $DESC
                eval hammer  content-view  publish --async --id $IDCOVI --organization $ORGA --description $DESC
done

######################################################################################
# Send Email to the team
######################################################################################
mail -s "SATELLITE : publish_content-view_auto.sh : DONE" $MAILING < $LOGS
