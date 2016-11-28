#!/bin/bash

## Look up the aws account number
aws_acct="$(aws ec2 describe-security-groups --group-names 'Default' --query 'SecurityGroups[0].OwnerId' --output text)"
admin_arns="$(aws iam get-user --output text --query User.Arn),arn:aws:iam::${aws_acct}:user/alan.garver"

## Hardcoded Variables - Demonstration
key_alias="alias/artifact-demo"
s3_bucket="${aws_acct}-artifact-demo"

aws cloudformation create-stack \
  --stack-name secure-artifact-demo \
  --template-body file://cfn/secure_artifact_demo.yml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=KMSEncryptorArns,ParameterValue=\"${admin_arns}\" \
    ParameterKey=KMSAdminArns,ParameterValue=\"${admin_arns}\" \
    ParameterKey=KMSDecryptorArns,ParameterValue=\"${admin_arns}\" \
    ParameterKey=KMSKeyAlias,ParameterValue=\"${key_alias}\" \
    ParameterKey=S3BucketName,ParameterValue=\"${s3_bucket}\"
