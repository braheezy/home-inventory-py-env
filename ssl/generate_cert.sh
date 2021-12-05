#/bin/bash

rm "privatekey.pem" "public.crt"

openssl genrsa 2048 > "privatekey.pem"
openssl req -new -config "ssl.conf" -key "privatekey.pem" -out "csr.pem"
openssl x509 -req -days 365 -in "csr.pem" -signkey "privatekey.pem" -out "public.crt"

# aws iam upload-server-certificate --server-certificate-name moreWildcardCN --certificate-body file://public.crt --private-key file://privatekey.pem

rm "csr.pem"