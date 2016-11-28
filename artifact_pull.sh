#!/bin/bash
###########################################################################
# Secure Artifact Pull Example
#
# This simple bash script is used only to demonstrate a pattern for using
# Amazon S3 and AWS KMS to securely push and pull build artifacts to 
# Amazon EC2 instances during launch convergence.  
#
# The script takes a single argument which is the sha256sum value of the 
# artifact that should be pulled, unpacked and decrypted to a converging
# instance.
###########################################################################
set -o pipefail
set -e
## Takes a single argument on the command line
artifact_sha=$1

## Look up the aws account number
aws_acct="$(aws ec2 describe-security-groups --group-names 'Default' --query 'SecurityGroups[0].OwnerId' --output text)"

## Hardcoded Variables - Demonstration
key_alias="alias/artifact-demo"
tmp_artifact_path="/tmp/artifact-demo/staging/${artifact_sha}"
s3_object_url="s3://${aws_acct}-artifact-demo/${artifact_sha}"

## check to see if an artifact exists in the s3 bucket with this sha
[ $(aws s3 ls ${s3_object_url}|wc -l) -eq 0 ] && echo "ERROR: can not find object in s3" && exit 2

## ensure we have a staging directory to unpack to
[ -d ${tmp_artifact_path}/validate ] || mkdir -p ${tmp_artifact_path}/validate
cd ${tmp_artifact_path}

## Get the bundle from s3 and unpack to tmp dir
aws s3 cp ${s3_object_url} ${tmp_artifact_path}/ --quiet
tar -xzf ${artifact_sha}

## decrypt the envelope key from KMS which was stored in the bundle
key=$(aws kms decrypt --ciphertext-blob fileb://<(cat ${artifact_sha}.key |base64 --decode) --output text --query Plaintext)

## decrypt the artifact bundle and unpack for sha validation
openssl enc -d -aes-256-cbc -in ${artifact_sha}.enc -out ${artifact_sha}.tar -k ${key}
tar -xzf ${artifact_sha}.tar -C ${tmp_artifact_path}/validate

## validate SHA of the just unpacked artifact
actual_sha="$(find ${tmp_artifact_path}/validate/ -type f |xargs shasum -a 256| awk '{print $1}'|shasum -a 256|awk '{print $1}')"

## error if the sha of the freshly unpacked artifact does not match the artifact id
if ! [ ${actual_sha} == ${artifact_sha} ] ; then
  echo "ERROR: Artifact Integrity Compromised, check artifact shasum failed, terminating job..."
  exit 99
fi

## cleanup
rm -rf ${tmp_artifact_path}/${artifact_sha}*

## else success message and we are done
echo "SUCCESS: Artifact Integrity Verified at ${tmp_artifact_path}/validate/"

