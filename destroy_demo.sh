#!/bin/bash

## Look up the aws account number
aws_acct="$(aws ec2 describe-security-groups --group-names 'Default' --query 'SecurityGroups[0].OwnerId' --output text)"

## Hardcoded Variables - Demonstration
s3_bucket_url="s3://${aws_acct}-artifact-demo"

aws s3 rm ${s3_bucket_url}/ --recursive
aws cloudformation delete-stack --stack-name secure-artifact-demo 
