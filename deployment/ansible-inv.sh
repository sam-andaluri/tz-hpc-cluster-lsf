#!/bin/bash

REGION="REGION"
RESOURCE_GROUP="RG"
API_KEY="KEY"

while getopts 'r:z:k:n:h' opt; do
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
        INSTANCE_LIST=`bx is ins --json | jq -r '.[] | .name + "," +  .network_interfaces[0].primary_ip.address + "," + .network_interfaces[0].floating_ips[0].address'`
        for PATTERN in on-prem burst misc
        do
            if [[ ! -f inventory-${PATTERN}.ini ]]; then
                echo "[${PATTERN}]" | sed 's/-//g' >> inventory-${PATTERN}.ini
            fi
        done
        for instance in $INSTANCE_LIST
        do
            INSTANCE_NAME=`echo ${instance} | cut -d "," -f 1`
            INSTANCE_PRIVATE_IP=`echo ${instance} | cut -d "," -f 2`
            INSTANCE_PUBLIC_IP=`echo ${instance} | cut -d "," -f 3`
            KEY=`bx is instance-initialization-values $INSTANCE_NAME --output JSON | jq -r '.keys[0] | .name + "," + .fingerprint'` 
            KEY_NAME=`echo ${KEY} | cut -d "," -f 1`
            if [[ "$INSTANCE_NAME" == *"on-prem"* && "$INSTANCE_NAME" != *"login"* ]]; then
                echo "$INSTANCE_NAME ansible_host=$INSTANCE_PRIVATE_IP ansible_ssh_private_key_file=~/.ssh/${KEY_NAME} ansible_user=root" >> inventory-on-prem.ini
            fi
            if [[ "$INSTANCE_NAME" == *"burst"* && "$INSTANCE_NAME" != *"login"* ]]; then
                echo "$INSTANCE_NAME ansible_host=$INSTANCE_PRIVATE_IP ansible_ssh_private_key_file=~/.ssh/${KEY_NAME} ansible_user=root" >> inventory-burst.ini
            fi
            if [[ "$INSTANCE_NAME" != *"on-prem"* && "$INSTANCE_NAME" != *"burst"* ]]; then
                echo "$INSTANCE_NAME ansible_host=$INSTANCE_PUBLIC_IP ansible_ssh_private_key_file=~/.ssh/${KEY_NAME} ansible_user=root" >> inventory-misc.ini
            fi
        done
        for PATTERN in on-prem burst
        do
            if [[ -f inventory-${PATTERN}.ini ]]; then
                echo "[${PATTERN}:vars]" | sed 's/-//g' >> inventory-${PATTERN}.ini
                echo "ansible_ssh_common_args=\"-F ./ssh-config-generated -J ${PATTERN}-login\"" >> inventory-${PATTERN}.ini
            fi            
        done
    fi
fi
