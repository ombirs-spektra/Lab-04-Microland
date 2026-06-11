# Exercise 2: Safely destroy infrastructure

## Scenario
In Exercise 1, you used Terraform to create an Ubuntu EC2 instance. In this exercise, you will remove that infrastructure safely and confirm that no learner-created EC2 resources remain active in your AWS lab environment.

This exercise focuses on teardown discipline, validation of results, and understanding how Terraform state reflects the infrastructure it manages.

## Objectives
After completing this exercise, you will be able to:

- Review Terraform-managed resources before destruction.
- Run `terraform destroy` to remove the EC2 instance.
- Confirm the destroy plan before proceeding.
- Verify in AWS that the EC2 instance is no longer active.
- Check Terraform state after cleanup.

## Task 1: Open the Terraform working directory
1. Connect to the lab virtual machine if you are not already signed in.
2. Open a terminal.
3. Change to the Terraform directory you used in Exercise 1.

   ```bash
   cd ~/terraform-ec2
   ```

4. Confirm that your Terraform files are still present.

   ```bash
   ls
   ```

## Task 2: Review the currently managed infrastructure
Before destroying resources, review what Terraform is currently managing.

1. List the resources in the Terraform state.

   ```bash
   terraform state list
   ```

2. Review the EC2 instance details from state.

   ```bash
   terraform state show aws_instance.ubuntu_vm
   ```

3. If needed, verify the EC2 instance from AWS CLI.

   ```bash
   aws ec2 describe-instances \
     --region <inject key="AwsRegion"></inject> \
     --query "Reservations[].Instances[].[InstanceId,State.Name,InstanceType,ImageId]" \
     --output table
   ```

> [!Note]
> Reviewing state before running `terraform destroy` helps you confirm exactly which resources are under Terraform management.

<validation step="1" />

## Task 3: Review the destroy plan
1. Generate the destroy plan.

   ```bash
   terraform plan -destroy
   ```

2. Review the output and confirm that Terraform plans to remove the EC2 instance you created in Exercise 1.
3. Make sure no unexpected resources are listed.

> [!Important]
> Always review the destroy plan before approving deletion. Terraform state and the execution plan together show what will be removed.

## Task 4: Destroy the EC2 instance
1. Run the destroy command.

   ```bash
   terraform destroy
   ```

2. When prompted for confirmation, type `yes` and press Enter.
3. Wait for Terraform to complete the destroy operation successfully.

Expected result:
- Terraform reports that the managed EC2 instance has been destroyed.

<validation step="2" />

## Task 5: Verify cleanup in Terraform and AWS
After Terraform completes the destroy operation, verify that the environment is clean.

1. Check Terraform state again.

   ```bash
   terraform state list
   ```

2. Verify the instance is no longer present in AWS.

   ```bash
   aws ec2 describe-instances \
     --region <inject key="AwsRegion"></inject> \
     --filters "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
     --query "Reservations[].Instances[].[InstanceId,State.Name,InstanceType]" \
     --output table
   ```

3. Confirm that your learner-created Ubuntu `t3.micro` instance is no longer listed as active.

> [!Note]
> A terminated instance may briefly appear during AWS cleanup. The important outcome for this lab is that no active learner-created EC2 instance remains billable.

<validation step="3" />

## Task 6: Confirm state awareness
Answer the following questions before moving on:

- What resource did Terraform manage in this lab?
- How did `terraform plan -destroy` help you confirm the intended action?
- Why is it important to verify both Terraform state and AWS after running `terraform destroy`?

## Summary
In this exercise, you reviewed Terraform-managed infrastructure, generated and reviewed a destroy plan, removed the EC2 instance with `terraform destroy`, and verified cleanup in both Terraform and AWS. You also reinforced the relationship between Terraform state, execution plans, and safe infrastructure teardown.
