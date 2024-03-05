#!/bin/bash

WORKSPACE_ID="WS"
RESOURCE_GROUP="RG"
API_KEY="KEY"

while getopts 'r:w:k:h' opt; do
  case "$opt" in
    r)
      RESOURCE_GROUP="$OPTARG"
      ;;
    w)
      WORKSPACE_ID="$OPTARG"
      ;;
    k)
      API_KEY="$OPTARG"
      ;;
    ?|h)
      echo "Usage: $(basename $0) -r resource_group -w workspace_id -k api_key"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

# Wait for a state change : success or failure.
waitFor()
{
    # debug
    # echo ">> $1"
    # echo ">> $2"
    # echo ">> $3"
    # echo ">> $4"
    # echo ">> $WS_STATUS"
    while ! [[ "$WS_STATUS" =~ ^($1|$2)$ ]]
    do
        sleep 30
        WS_STATUS=`bx schematics workspace get --id $3 --json | jq -r '.status'`
        #debug
        #echo ">>> $WS_STATUS"
        echo "Waiting for $1 or $2"
    done
    # if failed to provision, collect logs
    if [[ "$WS_STATUS" == "FAILED" && "$4" != "NULL" ]]
    then
        echo "Getting logs $3 $4"
        bx sch logs --id $3 --act-id $4 >> ${3}.log
    fi
}

# 1. Login using api key
if bx login --apikey $API_KEY > /dev/null 2>&1; then
    echo "Login succeeded"
    # 2. target a resource group
    if bx target -g $RESOURCE_GROUP > /dev/null 2>&1; then 
        echo "Targeting resource group $RESOURCE_GROUP"
        DESTROY_ACT_ID=`bx schematics destroy --id $WORKSPACE_ID --force | grep "Activity ID" | tr -s ' ' | cut -d ' ' -f 3`
        if [ $? -eq 0 ]; then 
            echo "Destroying resources for workspace $WORKSPACE_ID"
            WS_STATUS=`bx schematics workspace get --id $WORKSPACE_ID --json | jq -r '.status'`
            waitFor INPROGRESS FAILED $WORKSPACE_ID $DESTROY_ACT_ID
            waitFor INACTIVE FAILED $WORKSPACE_ID $DESTROY_ACT_ID
            if bx sch ws delete --id $WORKSPACE_ID --force > /dev/null 2>&1; then 
                echo "Deleting workspace $WORKSPACE_ID"
            else
                echo "Failed to delete workspace $WORKSPACE_ID"      
            fi
        else
            echo "Failed to destroy resources for workspace $WORKSPACE_ID"    
        fi
    else
        echo "Failed to target resource group $RESOURCE_GROUP"
    fi
else
     echo "Login failed"
fi
