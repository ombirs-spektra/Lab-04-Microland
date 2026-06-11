# Exercise 1: Create an EC2 instance using Terraform

## Introduction

In this exercise, you will create a Terraform configuration from scratch on the provided lab VM and use it to deploy a single Ubuntu Amazon EC2 instance in AWS. You will define the AWS provider, add one `aws_instance` resource, select an Ubuntu AMI appropriate for the lab region, and then run the standard Terraform workflow: `init`, `plan`, and `apply`.

You will use the preconfigured lab environment and IAM permissions already provided for this exercise. You do not need to enter AWS access keys manually.

## Objectives

After completing this exercise, you will be able to:

- Use the provided AWS lab environment and sign in with the supplied credentials.
- Create a Terraform configuration from scratch.
- Define an AWS provider for the lab region.
- Deploy one Ubuntu EC2 instance with instance type `t3.micro`.
- Run `terraform init`, `terraform plan`, and `terraform apply`.
- Verify that Terraform created the EC2 instance successfully.

## Lab credentials

### AWS console sign-in

1. Open the AWS sign-in URL:

   `<inject key="AwsConsoleUrl"></inject>`

2. Sign in with the following credentials:

   - **IAM user name:** `<inject key="IamUserName"></inject>`
   - **IAM password:** `<inject key="IamUserPassword"></inject>`

3. Confirm that you are working in:

   - **AWS account:** `<inject key="AwsAccountId"></inject>`
   - **AWS Region:** `<inject key="AwsRegion"></inject>`

### Lab VM and credential context

> [!Note]
> This lab uses a preconfigured lab VM. Terraform and AWS CLI are already installed. The AWS credentials or role access required for this exercise are already configured for you.
>
> Do **not** create or paste manual access keys into your Terraform files.

If you want to inspect the preconfigured environment on the lab VM, the bootstrap credential file is located at:

```bash
$LAB_HOME/cloudlabs-creds.env
```

## Task 1: Connect to the lab VM and prepare your working directory

1. Connect to the provided lab VM.
2. Open a terminal session.
3. Create and move into a new Terraform working directory:

```bash
mkdir -p ~/terraform-ec2-lab
cd ~/terraform-ec2-lab
```

4. Confirm that Terraform is installed:

```bash
terraform version
```

5. Confirm that AWS CLI can access the lab environment in the correct region:

```bash
aws sts get-caller-identity --region <inject key="AwsRegion"></inject>
```

Expected result:

- Terraform returns a version.
- AWS CLI returns caller identity information for account `<inject key="AwsAccountId"></inject>`.

## Task 2: Create the Terraform configuration

In this task, you will author the Terraform configuration from scratch.

1. In the `~/terraform-ec2-lab` directory, create a file named `main.tf`.
2. Add a Terraform configuration that defines:
   - the AWS provider
   - one EC2 instance resource
   - instance type `t3.micro`
   - an Ubuntu AMI appropriate for region `<inject key="AwsRegion"></inject>`

Use the following sample configuration as a starting point:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "<inject key="AwsRegion"></inject>"
}

resource "aws_instance" "ubuntu_vm" {
  ami           = "ami-xxxxxxxxxxxxxxxxx"
  instance_type = "t3.micro"

  tags = {
    Name = "terraform-ubuntu-vm"
    Lab  = "<inject key="DeploymentID"></inject>"
  }
}
```

3. Replace the placeholder AMI value with a valid Ubuntu AMI for region `<inject key="AwsRegion"></inject>`.

> [!Important]
> The AMI must be an Ubuntu image that is valid in the lab region. If needed, use the AWS console or AWS CLI to identify an Ubuntu AMI before continuing.

One example AWS CLI approach is shown below:

```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" "Name=state,Values=available" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
  --output text \
  --region <inject key="AwsRegion"></inject>
```

> [!Note]
> Owner `099720109477` is Canonical's public AWS account used for Ubuntu images.

4. Save the file after updating the AMI.

## Task 3: Initialize Terraform

1. In the same working directory, initialize the Terraform project:

```bash
terraform init
```

2. Review the output.

Expected result:

- Terraform downloads the AWS provider plugin.
- Initialization completes successfully.

<validation step="1"></validation>

## Task 4: Review the execution plan

1. Generate a Terraform execution plan:

```bash
terraform plan
```

2. Review the plan carefully.

Confirm that:

- Terraform will create exactly one EC2 instance.
- The resource type is `aws_instance`.
- The instance type is `t3.micro`.
- The selected AMI is an Ubuntu image valid for `<inject key="AwsRegion"></inject>`.

> [!Important]
> The required IAM permissions for this lab are already granted through the lab environment. If Terraform reports an authorization error, recheck that you are using the provided lab VM and preconfigured environment rather than manually supplied credentials.

## Task 5: Apply the configuration and create the EC2 instance

1. Deploy the infrastructure:

```bash
terraform apply
```

2. When prompted for confirmation, type:

```text
yes
```

3. Wait for Terraform to finish.

Expected result:

- Terraform reports that the apply operation completed successfully.
- One Ubuntu EC2 instance of type `t3.micro` is created.

## Task 6: Verify the deployment

1. Verify Terraform state:

```bash
terraform state list
```

Expected result:

- The output includes the EC2 resource, for example:

```text
aws_instance.ubuntu_vm
```

2. Verify the deployed instance from AWS CLI:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=<inject key="DeploymentID"></inject>" "Name=instance-state-name,Values=pending,running" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,InstanceType:InstanceType,ImageId:ImageId,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table \
  --region <inject key="AwsRegion"></inject>
```

3. Optionally, verify the instance in the AWS Management Console:
   - Open **EC2**.
   - Select **Instances**.
   - Confirm that your Ubuntu `t3.micro` instance is present.

<validation step="2"></validation>

## Success criteria

You have completed this exercise successfully if:

- You created a valid Terraform configuration from scratch.
- Your configuration includes an AWS provider block.
- Your configuration includes one `aws_instance` resource.
- The instance type is `t3.micro`.
- The AMI is a valid Ubuntu AMI for `<inject key="AwsRegion"></inject>`.
- `terraform init`, `terraform plan`, and `terraform apply` completed successfully.
- Terraform state and AWS both confirm that the EC2 instance exists.

## Summary

In this exercise, you used the preconfigured lab VM and IAM access provided by the environment to create an EC2 instance with Terraform. You defined the AWS provider, created a single `aws_instance` resource, selected a region-appropriate Ubuntu AMI, and verified the deployment by using both Terraform state and the AWS CLI.
