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

  workspace_dir=""
  for candidate in \
    "$HOME/environment" \
    "$HOME/terraform-lab" \
    "$HOME/terraform" \
    "$HOME/labfiles" \
    "$HOME/project" \
    "$HOME/projects"; do
    if [ -d "$candidate" ]; then
      if find "$candidate" -maxdepth 3 -type f \( -name "*.tf" -o -name "*.tfvars" \) 2>/dev/null | grep -q .; then
        workspace_dir="$candidate"
        break
      fi
    fi
  done

  if [ -z "$workspace_dir" ]; then
    tf_file=$(find "$HOME" -maxdepth 4 -type f -name "*.tf" 2>/dev/null | head -n 1)
    if [ -n "${tf_file:-}" ]; then
      workspace_dir=$(dirname "$tf_file")
    fi
  fi

  failure_reason=""
  matched_file=""

  if [ -z "$workspace_dir" ] || [ ! -d "$workspace_dir" ]; then
    failure_reason="Terraform workspace was not found under the learner home directory."
  else
    tf_files=$(find "$workspace_dir" -maxdepth 3 -type f -name "*.tf" 2>/dev/null)
    if [ -z "$tf_files" ]; then
      failure_reason="No Terraform .tf files were found in workspace '$workspace_dir'."
    else
      for file in $tf_files; do
        if grep -Eiq 'provider[[:space:]]+"aws"|required_providers[[:space:][:punct:][:alnum:]\n\r\t]*aws' "$file" && \
           grep -Eiq 'resource[[:space:]]+"aws_instance"' "$file" && \
           grep -Eiq 'instance_type[[:space:]]*=[[:space:]]*"t3\.micro"' "$file" && \
           grep -Eiq 'ami[[:space:]]*=|data[[:space:]]+"aws_ami"|owner[s]?[[:space:]]*=.*099720109477|ubuntu' "$file"; then
          matched_file="$file"
          break
        fi
      done

      if [ -z "$matched_file" ]; then
        combined_tf=$(find "$workspace_dir" -maxdepth 3 -type f -name "*.tf" -exec cat {} + 2>/dev/null)
        echo "$combined_tf" | grep -Eiq 'provider[[:space:]]+"aws"|required_providers[[:space:][:punct:][:alnum:]\n\r\t]*aws'
        provider_rc=$?
        echo "$combined_tf" | grep -Eiq 'resource[[:space:]]+"aws_instance"'
        instance_rc=$?
        echo "$combined_tf" | grep -Eiq 'instance_type[[:space:]]*=[[:space:]]*"t3\.micro"'
        type_rc=$?
        echo "$combined_tf" | grep -Eiq 'ami[[:space:]]*=|data[[:space:]]+"aws_ami"|owner[s]?[[:space:]]*=.*099720109477|ubuntu'
        ami_rc=$?

        if [ $provider_rc -ne 0 ]; then
          failure_reason="Terraform configuration does not contain an AWS provider definition in workspace '$workspace_dir'."
        elif [ $instance_rc -ne 0 ]; then
          failure_reason="Terraform configuration does not contain an aws_instance resource in workspace '$workspace_dir'."
        elif [ $type_rc -ne 0 ]; then
          failure_reason="Terraform configuration does not set the EC2 instance type to t3.micro in workspace '$workspace_dir'."
        elif [ $ami_rc -ne 0 ]; then
          failure_reason="Terraform configuration does not show an Ubuntu AMI selection approach in workspace '$workspace_dir'."
        else
          failure_reason="Terraform configuration files were found, but the expected AWS provider, aws_instance, t3.micro, and Ubuntu AMI checks did not align in a practical workspace layout."
        fi
      fi

      if [ -z "$failure_reason" ]; then
        init_ok=false
        if [ -d "$workspace_dir/.terraform" ] && [ -f "$workspace_dir/.terraform.lock.hcl" ]; then
          init_ok=true
        fi

        if [ "$init_ok" != "true" ]; then
          for log_file in \
            "$workspace_dir/terraform-init.log" \
            "$workspace_dir/init.log" \
            "$workspace_dir/.init.log"; do
            if [ -f "$log_file" ] && grep -Eiq 'Terraform has been successfully initialized|successfully initialized' "$log_file"; then
              init_ok=true
              break
            fi
          done
        fi

        if [ "$init_ok" != "true" ]; then
          failure_reason="Terraform workspace '$workspace_dir' does not show evidence that 'terraform init' completed successfully (.terraform directory and lock file, or a success log, were not found)."
        fi
      fi
    fi
  fi

  set -e

  if [ -z "$failure_reason" ]; then
    found=true
    cat <<EOF
{"Status":"Succeeded","Message":"Terraform workspace '$workspace_dir' contains valid configuration for AWS with an aws_instance resource, instance type t3.micro, an Ubuntu AMI selection approach, and successful terraform init evidence. Verified for deployment $DEPLOYMENT_ID in account $ACCOUNT_ID, region $AWS_REGION."}
EOF
    exit 0
  fi

  if [ "$found" != "true" ]; then
    sleep 10
  fi
done

cat <<EOF
{"Status":"Failed","Message":"Validation failed after $count attempts: $failure_reason Account $ACCOUNT_ID, deployment $DEPLOYMENT_ID, region $AWS_REGION."}
EOF
exit 0
