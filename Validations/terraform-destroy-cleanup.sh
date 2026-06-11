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

  workspace_root="${HOME}/terraform-ec2-lab"
  if [ ! -d "$workspace_root" ]; then
    workspace_root="${HOME}/lab-files/terraform-ec2-lab"
  fi

  tf_files_present=false
  if [ -d "$workspace_root" ] && find "$workspace_root" -maxdepth 1 \( -name "*.tf" -o -name "*.tfstate" -o -name ".terraform" \) | grep -q .; then
    tf_files_present=true
  fi

  state_clean=false
  if [ -d "$workspace_root" ] && command -v terraform >/dev/null 2>&1; then
    if terraform -chdir="$workspace_root" state list 2>/dev/null | grep -q '^aws_instance\.'; then
      state_clean=false
    else
      state_clean=true
    fi
  fi

  instance_ids=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
              "Name=tag:DeploymentID,Values=$DEPLOYMENT_ID" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text 2>/dev/null)
  aws_rc=$?

  leftover_active=false
  if [ $aws_rc -eq 0 ] && [ -n "$instance_ids" ] && [ "$instance_ids" != "None" ]; then
    leftover_active=true
  fi

  set -e

  if [ "$tf_files_present" = "true" ] && [ "$state_clean" = "true" ] && [ "$leftover_active" = "false" ]; then
    found=true
    cat <<EOF
{"Status":"Succeeded","Message":"Terraform cleanup verified for deployment '$DEPLOYMENT_ID'. Terraform workspace artifacts were found, terraform state no longer tracks an aws_instance resource, and AWS account $ACCOUNT_ID in region $AWS_REGION has no active learner-created EC2 instances tagged with DeploymentID=$DEPLOYMENT_ID. Cleanup and state awareness requirements were satisfied."}
EOF
    exit 0
  fi

  if [ "$found" != "true" ]; then
    sleep 10
  fi
done

cat <<EOF
{"Status":"Failed","Message":"Terraform destroy cleanup could not be verified for deployment '$DEPLOYMENT_ID' after $count attempts. Expected terraform workspace artifacts, no aws_instance entries in terraform state, and no active learner-created EC2 instances in account $ACCOUNT_ID region $AWS_REGION tagged with DeploymentID=$DEPLOYMENT_ID. This indicates destroy, cleanup verification, or Terraform state awareness is incomplete."}
EOF
exit 0
