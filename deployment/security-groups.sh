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
      echo "Usage: $(basename $0) -r resource_group -z region -k api_key -n name"
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
        ON_PREM_SUBNET=`bx is subnets --output json | jq -r '.[] | .name + "," + .ipv4_cidr_block' | grep "on-prem-subnet" | cut -d"," -f2`
        BURST_SUBNET=`bx is subnets --output json | jq -r '.[] | .name + "," + .ipv4_cidr_block' | grep "burst-subnet" | cut -d"," -f2`
        ON_PREM_SG=`bx is sgs --output json | jq -r '.[] | .id + "," + .name' | grep on-prem-sg | cut -d"," -f1`
        BURST_SG=`bx is sgs --output json | jq -r '.[] | .id + "," + .name' | grep burst-sg | cut -d"," -f1`
        bx is sg-rulec $ON_PREM_SG inbound all --remote $BURST_SUBNET
        bx is sg-rulec $BURST_SG inbound all --remote $ON_PREM_SUBNET
    fi
fi
