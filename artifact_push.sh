#!/bin/bash
###########################################################################
# Secure Artifact Push Example
#
# This simple bash script is used only to demonstrate a pattern for using
# Amazon S3 and AWS KMS to securely push and pull build artifacts to 
# Amazon EC2 instances during launch convergence.  
#
# The script takes a single argument which is the path to the source file 
# or directory that should be bundled, encrypted and pushed to Amazon S3.
###########################################################################
set -o pipefail
set -e
## Input a single argumet as the path to the source file or directory to push
artifact_source=$1

## Look up the aws account number
aws_acct="$(aws ec2 describe-security-groups --group-names 'Default' --query 'SecurityGroups[0].OwnerId' --output text)"

## Hardcoded Variables - Demonstration
key_alias="alias/artifact-demo"
artifact_build_path="/tmp/artifact-demo/build"
s3_bucket_url="s3://${aws_acct}-artifact-demo"

## Generate the data key and ciphertext from AWS KMS
kms_gen=$(aws kms generate-data-key --key-id ${key_alias} --key-spec AES_256 --output text --query [Plaintext,CiphertextBlob])
kms_key=$(echo "${kms_gen}"|cut -f 1)
kms_ciphertext=$(echo "${kms_gen}"|cut -f 2)

## Get SHA of the artifact (some operating systems use 'shasum -a 256', some use 'sha256sum')
artifact_sha="$(find ${artifact_source} -type f |xargs shasum -a 256|awk '{print $1}'|shasum -a 256|awk '{print $1}')"

## ensure we have a build directory 
[ -d ${artifact_build_path} ] || mkdir -p ${artifact_build_path}

## tar and encrypt the artifact (openssl required)
bundle_prefix="${artifact_build_path}/${artifact_sha}"
tar -czf ${bundle_prefix}.tar --directory $(dirname ${artifact_source}) $(basename ${artifact_source})
openssl enc -aes-256-cbc -salt -in ${bundle_prefix}.tar -out ${bundle_prefix}.enc -k ${kms_key}

## bundle the ciphertext and encrypted artifact
echo "${kms_ciphertext}">${bundle_prefix}.key
cd ${artifact_build_path}
tar -czf ${artifact_sha} ${artifact_sha}.enc ${artifact_sha}.key
cd - > /dev/null

## push to s3 and cleanup
aws s3 cp ${bundle_prefix} ${s3_bucket_url} --quiet --sse aws:kms
rm -f ${bundle_prefix}.*

## print the artifact id
echo "$artifact_sha"
