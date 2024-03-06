create: clean vpc sshkeys onprem burst secgrp sshcfg ansibleinv integrate

destroy: delete 

.PHONY: create destroy

.EXPORT_ALL_VARIABLES:
    RESOURCE_GROUP=`jq -r '.resource_group' ../keys/sam/secrets.json`
    ON_PREM_REGION=`jq -r '.zone' on-prem-params.json | cut -f1,2 -d "-"`
	BURST_REGION=`jq -r '.zone' burst-params.json | cut -f1,2 -d "-"`
	IC_API_KEY=`jq -r '.api_key' ../keys/sam/secrets.json`
	VPC_NAME="tz-test-1"
	SSH_KEY_NAME="tz-test-lsf"
clean:
	-rm on-prem-out.json
	-rm burst-out.json
	-rm inventory-burst.ini
	-rm inventory-misc.ini
	-rm inventory-on-prem.ini
	-rm inventory.ini
	-rm ssh-config-generated
onprem:
	./create.sh on-prem-params.json workspace.json ../keys/sam/secrets.json
burst:
	./create.sh burst-params.json workspace.json ../keys/sam/secrets.json
vpc:
	./vpc.sh 
