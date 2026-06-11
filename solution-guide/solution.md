# Solution Guide

## Lab focus
Learners build and manage a single Ubuntu EC2 instance with Terraform on a pre-provisioned AWS lab VM. Git, GitHub, and Jenkins are out of scope. IAM access is assumed to be preconfigured for the learner session.

## Expected end state
By the end of the lab, the learner should have:
- A local Terraform project directory on the lab VM
- A valid `main.tf` or equivalent Terraform configuration
- An AWS provider configured in Terraform
- One `aws_instance` resource using an Ubuntu AMI
- Instance type set to `t3.micro`
- A successful `terraform init`
- A successful `terraform plan`
- A successful `terraform apply`
- A verifiable EC2 instance in AWS and in Terraform state
- A successful `terraform destroy`
- No leftover EC2 resources or active Terraform-managed infrastructure

## Exercise 1 — Create an EC2 instance using Terraform

### Expected learner outcome
Learners should create Terraform configuration from scratch and deploy one Ubuntu EC2 instance.

### Expected Terraform pattern
A minimal valid configuration should resemble:

```hcl
provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Ubuntu AMI lookup pattern acceptable for the lab region
# Example using a data source or a pinned region-appropriate AMI.
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "ubuntu_vm" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "lab-ubuntu-tf"
  }
}
```

Acceptable alternatives:
- A region-specific Ubuntu AMI ID hardcoded for the selected AWS region
- A data source approach for latest Ubuntu LTS AMI, if the region filters are correct

Not acceptable:
- Wrong AMI owner
- Amazon Linux when the lab explicitly requires Ubuntu
- Any instance type other than `t3.micro`
- Multiple instances
- Extra infrastructure unrelated to the task

### Rubric
Full credit when all of the following are present:
- Terraform provider block exists for AWS
- Exactly one EC2 instance resource is defined for the learner task
- Ubuntu AMI selection is valid for the target region
- `instance_type = "t3.micro"`
- `terraform init` succeeds
- `terraform plan` shows the intended single instance
- `terraform apply` completes successfully

Partial credit conditions:
- Provider is correct but AMI lookup is malformed
- Instance type is correct but AMI is wrong
- Configuration is mostly correct but `terraform init` fails due to syntax/provider issues
- Plan works but apply fails due to permissions, region mismatch, or subnet/VPC assumptions

### Verification steps for facilitator
Use Terraform state first, then AWS CLI.

Terraform checks:
```bash
terraform init
terraform plan
terraform state list
terraform show
```

AWS CLI checks:
```bash
aws sts get-caller-identity
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lab-ubuntu-tf" \
  --region us-east-1
```

If tags are not used, verify by instance state and launch time:
```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --query 'Reservations[].Instances[?InstanceType==`t3.micro`].[InstanceId,State.Name,ImageId,InstanceType]'
```

### Common pitfalls
- Wrong AWS region in provider or CLI environment
- IAM policy propagation delay if permissions were just attached
- Missing default VPC/subnet assumptions in some lab accounts
- Ubuntu AMI filters using the wrong owner ID
- Using an AMI that is not available in the selected region
- Security group omitted only if the lab/account default SG is restricted; if networking is needed, explicit SG may be required
- Instance state lag: AWS may report `pending` briefly after apply

## Exercise 2 — Safely destroy infrastructure

### Expected learner outcome
Learners should remove the Terraform-managed EC2 instance and confirm cleanup.

### Expected workflow
The learner should run:
```bash
terraform destroy
```

Facilitator should expect a confirmation prompt unless auto-approved was used. The destroy plan should show only the EC2 instance scheduled for deletion.

### Rubric
Full credit when:
- `terraform destroy` completes successfully
- Terraform state no longer contains the EC2 instance resource
- AWS CLI confirms the instance is terminated or absent
- No billable learner-created EC2 instance remains

Partial credit conditions:
- Destroy was planned but not applied
- Instance is terminated but still appears briefly in AWS due to eventual consistency
- Terraform state still shows the resource because destroy was interrupted
- Instance exists but is stopped rather than terminated

### Verification steps for facilitator
Terraform checks:
```bash
terraform destroy
terraform state list
terraform show
```

AWS CLI checks:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lab-ubuntu-tf" \
  --region us-east-1
```

A more explicit termination-state query:
```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --query 'Reservations[].Instances[?InstanceType==`t3.micro`].[InstanceId,State.Name]'
```

Expected end-state is no active instance. If the instance still appears as `shutting-down`, recheck after a short delay.

### Common pitfalls
- User confirms destroy before reading the plan
- Terraform state removed manually before AWS resources are actually deleted
- Region mismatch causes the learner to believe destroy worked because the wrong region was queried
- AWS eventual consistency shows a terminated instance for a short period
- IAM permissions allow create but not delete if policy scoping was incorrectly narrowed

## Facilitator notes
- IAM and permissions are preconfigured for the learner environment; do not send learners to create or modify AWS credentials manually.
- This lab is intentionally limited to Terraform and AWS CLI verification.
- Do not introduce Git/GitHub/Jenkins steps; they are not part of the approved flow.
- If the instance launch fails, first confirm region, AMI validity, and default VPC/subnet availability before treating it as a Terraform syntax issue.
- If the apply succeeds but SSH is unavailable, that is not a lab failure unless the task explicitly requires SSH access; the lab outcome is resource creation and cleanup.
