#!/bin/bash
set -uo pipefail

# Platform-injected vars (do NOT re-define):
#   ACCOUNT_ID    — AWS account id
#   DEPLOYMENT_ID — CloudLabs deployment id
#   AWS_REGION    — primary region

count=0
found=false
while [ $count -lt 3 ] && [ "$found" != "true" ]; do
  count=$((count + 1))
  set +e

  workspace_dir="$HOME/terraform-ec2-lab"
  tf_ok=false
  state_ok=false
  aws_ok=false
  resource_addr=""
  instance_id=""
  instance_state=""

  if [ -d "$workspace_dir" ]; then
    cd "$workspace_dir" || exit 0

    terraform init -input=false -no-color >/tmp/validation2-init.log 2>&1
    init_rc=$?

    terraform state list >/tmp/validation2-state-list.log 2>&1
    state_list_rc=$?

    if [ $init_rc -eq 0 ] && [ $state_list_rc -eq 0 ]; then
      tf_ok=true
      if grep -q "aws_instance" /tmp/validation2-state-list.log; then
        resource_addr=$(grep "aws_instance" /tmp/validation2-state-list.log | head -n 1)
        terraform state show "$resource_addr" >/tmp/validation2-state-show.log 2>&1
        state_show_rc=$?

        if [ $state_show_rc -eq 0 ] && grep -q 'instance_type *= *"t3.micro"' /tmp/validation2-state-show.log; then
          instance_id=$(awk -F' = ' '/^id = / {gsub(/"/,"",$2); print $2; exit}' /tmp/validation2-state-show.log)
          ami_id=$(awk -F' = ' '/^ami = / {gsub(/"/,"",$2); print $2; exit}' /tmp/validation2-state-show.log)
          if [ -n "$instance_id" ] && [ -n "$ami_id" ]; then
            state_ok=true
          fi
        fi
      fi
    fi
  fi

  if [ -n "$instance_id" ]; then
    aws ec2 describe-instances \
      --instance-ids "$instance_id" \
      --region "$AWS_REGION" \
      --query 'Reservations[].Instances[].{State:State.Name,InstanceType:InstanceType,ImageId:ImageId,Owner:OwnerId}' \
      --output text >/tmp/validation2-ec2.log 2>&1
    ec2_rc=$?

    if [ $ec2_rc -eq 0 ]; then
      read -r instance_state instance_type image_id owner_id < /tmp/validation2-ec2.log
      if [ "$owner_id" = "$ACCOUNT_ID" ] && [ "$instance_type" = "t3.micro" ] && [ "$image_id" = "$ami_id" ] && { [ "$instance_state" = "pending" ] || [ "$instance_state" = "running" ]; }; then
        aws_ok=true
      fi
    fi
  fi

  set -e

  if [ "$tf_ok" = "true" ] && [ "$state_ok" = "true" ] && [ "$aws_ok" = "true" ]; then
    found=true
    cat <<EOF
{"Status":"Succeeded","Message":"Terraform workflow is initialized in '$workspace_dir'; terraform state contains EC2 resource '$resource_addr'; and EC2 instance '$instance_id' exists in account $ACCOUNT_ID in region $AWS_REGION using AMI '$ami_id', type 't3.micro', and state '$instance_state'."}
EOF
    exit 0
  fi

  if [ "$found" != "true" ]; then
    sleep 10
  fi
done

cat <<EOF
{"Status":"Failed","Message":"Expected a Terraform-managed Ubuntu EC2 deployment in '$HOME/terraform-ec2-lab' after $count attempts. Confirm terraform init and apply succeeded, terraform state lists an aws_instance resource with instance type 't3.micro', and AWS shows the referenced EC2 instance in account $ACCOUNT_ID in region $AWS_REGION with state 'pending' or 'running'."}
EOF
exit 0
