#!/bin/bash

REGION="us-south"
RESOURCE_GROUP="tz-test"
KEY="BLAH"
NAME="NAME"
while getopts 'r:z:k:n:h' opt; do
  case "$opt" in
    r)
      RESOURCE_GROUP="$OPTARG"
      ;;
    z)
      REGION="$OPTARG"
      ;;
    k)
      KEY="$OPTARG"
      ;;
    n)
      NAME="$OPTARG"
      ;;
    ?|h)
      echo "Usage: $(basename $0) -r resource_group -z region -k api_key -n name"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"
echo "Region = $REGION"
echo "Resource Group = $RESOURCE_GROUP"
echo "Key = $KEY"
echo "Name = $NAME"

