#!/bin/bash

WORKSPACE_FILE="WS"
PARAMS_FILE="RG"
SECRETS_FILE="KEY"

while getopts 'p:w:s:h' opt; do
  case "$opt" in
    p)
      PARAMS_FILE="$OPTARG"
      ;;
    w)
      WORKSPACE_FILE="$OPTARG"
      ;;
    s)
      SECRETS_FILE="$OPTARG"
      ;;
    ?|h)
      echo "Usage: $(basename $0) -w workspace.json -p params.json -s secrets.json"
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
if bx login --apikey `jq -r '.api_key' $SECRETS_FILE` > /dev/null 2>&1; then
    echo "Login succeeded"
    # 2. target a resource group
    RG=`jq -r '.resource_group' $SECRETS_FILE`
    if bx target -g $RG > /dev/null 2>&1; then 
        echo "Targeting resource group $RG"
        OUT_FILE=`echo $PARAMS_FILE | sed 's/params/out/g'`
        # 3. Merge params, secrets and workspace config to generate a template
        if [ ! -f $OUT_FILE ]; then
            echo "Preparing $OUT_FILE" 
            prepare.py -p $PARAMS_FILE -w $WORKSPACE_FILE -s $SECRETS_FILE -o $OUT_FILE
        fi
        echo "Using workspace file $OUT_FILE"
        # 4. Create a workspace
        WS_ID=`bx schematics workspace new -f $OUT_FILE --json | jq -r '.id'`
        #echo $WS_ID >> ${WS_ID}.state   
        if [ $? -eq 0 ]; then 
            echo "Created workspace $WS_ID"
            WS_STATUS=`bx schematics workspace get --id $WS_ID --json | jq -r '.status'`
            echo "Current workspace status $WS_STATUS"
            waitFor INACTIVE NULL $WS_ID NULL
            echo "Plan workspace $WS_ID"
            # 5. Schematics plan
            PLAN_ACT_ID=`bx schematics plan --id $WS_ID | grep "Activity ID" | tr -s ' ' | cut -d ' ' -f 3`
            if [ $? -eq 0 ]; then 
                echo "Generating plan with id $PLAN_ACT_ID"
                WS_STATUS=`bx schematics workspace get --id $WS_ID --json | jq -r '.status'`
                echo "Current plan status $WS_STATUS"
                # 6. Plan state transitions from inprogress to inactive
                waitFor INPROGRESS FAILED $WS_ID $PLAN_ACT_ID
                waitFor INACTIVE FAILED $WS_ID $PLAN_ACT_ID
                # 6. Schematics apply
                APPLY_ACT_ID=`bx schematics apply --id $WS_ID --force | grep "Activity ID" | tr -s ' ' | cut -d ' ' -f 3`
                if [ $? -eq 0 ]; then
                    echo "Apply plan with id $APPLY_ACT_ID"
                    WS_STATUS=`bx schematics workspace get --id $WS_ID --json | jq -r '.status'`
                    # 6. Plan state transitions from inprogress to active
                    waitFor INPROGRESS FAILED $WS_ID $APPLY_ACT_ID
                    waitFor ACTIVE FAILED $WS_ID $APPLY_ACT_ID
                else 
                    echo "Failed to apply"
                fi
            else 
                echo "Failed to plan"    
            fi
        else
            echo "Failed to create workspace"
        fi
    else
        echo "Failed to target resource group $RG"
    fi
else
    echo "Login failed"
fi

