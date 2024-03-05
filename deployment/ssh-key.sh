#!/bin/bash

REGION="REGION"
RESOURCE_GROUP="RG"
API_KEY="KEY"
KEY_NAME="NAME"

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
    n)
      KEY_NAME="$OPTARG"
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
        ssh-keygen -t rsa -f ~/.ssh/${KEY_NAME} -q -P ""
        bx is keyc $KEY_NAME @~/.ssh/${KEY_NAME}.pub
    fi
fi
