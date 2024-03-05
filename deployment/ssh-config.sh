#!/bin/bash

REGION="REGION"
RESOURCE_GROUP="RG"
API_KEY="KEY"

while getopts 'r:z:k:h' opt; do
  case "$opt" in
    r)
      RESOURCE_GROUP="$OPTARG"
      ;;
    z)
      REGION="$OPTARG"
      ;;
    k)
      API_KEY="$OPTARG"
      ;;
    ?|h)
      echo "Usage: $(basename $0) -r resource_group -z region -k api_key"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

# 1. Login using api key
if bx login --apikey $API_KEY > /dev/null 2>&1; then
    echo "Login succeeded"
    # 2. target a resource group
    if bx target -g $RESOURCE_GROUP -r $REGION > /dev/null 2>&1; then 
        echo "Targeting resource group $RESOURCE_GROUP and region $REGION"
        # 3. Find all instances in this resource group
        for instance in `bx is ins --json | jq -r '.[] | .name + "," +  .network_interfaces[0].primary_ip.address + "," + .network_interfaces[0].floating_ips[0].address'`
        do
            INSTANCE_NAME=`echo ${instance} | cut -d "," -f 1`
            INSTANCE_PRIVATE_IP=`echo ${instance} | cut -d "," -f 2`
            INSTANCE_PUBLIC_IP=`echo ${instance} | cut -d "," -f 3`
            PATTERN="login"
            echo "Host $INSTANCE_NAME" >> ssh-config-generated
            if [[ "$INSTANCE_NAME" == *"$PATTERN"* && "$INSTANCE_PUBLIC_IP" != "" ]]; then
                echo "   HostName $INSTANCE_PUBLIC_IP" >> ssh-config-generated
            else
                echo "   HostName $INSTANCE_PRIVATE_IP" >> ssh-config-generated
            fi
            echo "   User root" >> ssh-config-generated
            KEY=`bx is instance-initialization-values $INSTANCE_NAME --output JSON | jq -r '.keys[0] | .name + "," + .fingerprint'` 
            KEY_NAME=`echo ${KEY} | cut -d "," -f 1`
            CLOUD_KEY_FPRINT=`echo ${KEY} | cut -d "," -f 2`
            FILE_KEY_FPRINT=`ssh-keygen -lf ~/.ssh/${KEY_NAME} | cut -d " " -f 2`
            if [[ -f ~/.ssh/${KEY_NAME} && "$CLOUD_KEY_FPRINT" == "$FILE_KEY_FPRINT" ]]; then
                echo "   IdentityFile ~/.ssh/${KEY_NAME}" >> ssh-config-generated
            fi
        done
    fi
fi
