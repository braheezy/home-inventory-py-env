#/bin/bash 

pushd ssl
# Run the script to create and upload a new SSL cert to IAM.
./generate_cert.sh
# Obtain tha ARN of the cert for TF to use.
# TEMP_FILE="tmp.yml"
# aws iam get-server-certificate --server-certificate-name home-inventory-eb-x509 > $TEMP_FILE
# CERT_ARN=$(cat $TEMP_FILE | yq e '.ServerCertificate.ServerCertificateMetadata.Arn' -)
# rm $TEMP_FILE
popd

# Put secrets in environmant
. secrets.sh

terraform apply -auto-approve

echo "Remember to confirm the CodeStarConnection in the CodePipeline service. Under Source, keep editing until you get to Update Pending Connection"

rm ssl/public.crt ssl/privatekey.pem