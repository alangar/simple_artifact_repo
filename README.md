#Simple Secure Build Artifact Repository with AWS
This is a set of scripts that can be used to demonstrate good best practices around using S3 and KMS to host a simple artifact repository.

The following scripts are included:

##setup_demo.sh

A setup script that will use the AWS CLI on your workstation to create a cloudformation stack.  The template that it runs can be found in cfn/secure_artifact_demo.yml.  It will create a stack with the following resources in the account you currently have configured with the awscli:

* IAM Role for Artifact Client users called ArtifactClientRole which is used to associate ec2 instances to KMS Key and S3 Bucket policies
* Instance Profile that references the ArtifactClientRole which is used to associate the role to instances at launch
* S3 Bucket used as the Artifact S3 Repository
* S3 Bucket Policy that allows the ArtifactClientRole to get objects from the S3 Bucket
* KMS Key called ArtifactDemoKMSKey with a policy that allows the ArtifactClientRole to Decrypt, and sets up Decryptors, Encryptors and Admins
* KMS Alias that gives a named Alias to the ArtifactDemoKMSKey for use in later scripts

You may need to edit the line that starts with "admin_arns" to include a specified user account if it differs from the account you are authenticated with in the awscli, see the commented version as an example.

Simply run the script to set up the resources in your account.


##artifact_push.sh

A bash script that simulates publishing an artifact which compresses and client side encrypts a file or directory locally with the KMS Key built by the setup script before pushing to s3.

The script accepts a single argument which is any relative or static path to a file or directory on the system where you are running the script.  The script will:

* generate-data-key from KMS using the Alias set up by setup_demo.sh
* calculate a nested shasum from the file or directory provided as an argument ($1)
* create a tmp directory if it doesnt exsit as a working directory
* tar the contents of the directory or file to a .tar
* encrypt the file using aes256 openssl through the open text of the data-key from KMS
* bundle the encrypted tar and CipherText from the data-key from KMS into a file named with the sha256sum
* copy the encrypted bundle to the S3 Bucket created by setup_demo.sh using aws:kms server side encryption
* return the artifact sha id on the commandline

The object can now be found in the S3 bucket but only decrypted if you have permission to decrypt with the KMS key created by the setup_demo.sh script

##artifact_pull.sh

A bash script that simulates the consumption of an artifact which pulls an object from S3, decrypts the CipherText wrapped with the encrypted artifact with a call to KMS, decrypts the artifact with openssl aes256 using the plain text of the now decrypted key locally, and unpacks the decrypted tar onto the system where it is run.

The script accepts a single argument which is the sha id that was returned by the artifact_push.sh script. The script will:

* create a tmp directory if it does not exist
* pull the object from S3 
* untar the content to the tmp directory 
* call kms to decrypt the CipherText wrapped in the artifact
* openssl decrypt the encrypted content with the plain text returned by KMS
* untar the contents of the newly decrypted package
* validate the sha256sum of the decrypted contents
* exit with a 99 return code if the object does not match, or clean up the temp directory and exit 0 with success

##destroy_demo.sh

A bash script that simply has 2 steps:

1.  remove all objects from the S3 Bucket created by setup_demo.sh
2.  delete the cloudformation stack created by setup_demo.sh

Run this to destroy the demo, WARNING this will destroy all object in the S3 Bucket!


