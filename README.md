# Purpose
At the press of a "button", the AWS resources to host `HomeInventoryPy` are created. 

Source projects:
- [Backend](https://github.com/mbraha/home-inventory-py-backend)
- [Frontend](https://github.com/mbraha/home-inventory-py-frontend)

# Setup
All of the following variables are required. Set them in `terraform.tfvars`. Defaults can be found there.

| Variable                                  | Description |
| ----------------------------------------- | ----------------------------------------- |
| `mongo_cluster_name`                      | The desired name of the created MongoDB Atlas cluster. |
| `mongo_project_name`                      | The desired name of the created MongoDB Atlas project. |
| `mongo_cluster_region`                    | The region to deploy the MongoDB Atlas resource. See this important [note](#id-1). |
| `aws_region`                              | The AWS region to deploy resources to. See this important [note](#id-2). |
| `aws_iam_role_name`                       | The name of the IAM role that will be created to manage access to all resources. |
| `aws_s3_bucket_name`                      | The name of S3 bucket to store build artifacts. |
| `aws_codebuild_project_name`              | The name of the CodeBuild project. |
| `aws_elastic_beanstalk_application_name`  | The name of the Elastic Beanstalk application. |
| `aws_codestarconnections_connection_name` | The name of the CodeStar Connection. |
| `aws_codepipeline_name`                   | The name of the CodePipeline project. |
| `aws_codepipeline_source_repo`            | The name of the repository that should be used for the CodePipeline project. |
| `aws_amplify_app_name`                    | The name of the AWS Amplify application. |
| `aws_amplify_repo_url`                    | The URL to the GitHub repository that should be used for the AWS Amplify project. |

The following are sensitive variables. Copy `secrets-template.sh` to `secrets.sh` and set the values.

| Variable                              | Description |
| ------------------------------------- | ------------------------------------- |
| `AWS_ACCESS_KEY_ID`                   | The Access Key for an AWS account with Admin privileges. |
| `AWS_SECRET_ACCESS_KEY`               | The Secret Key for an AWS account with Admin privileges. |
| `MONGODB_ATLAS_PUBLIC_KEY`            | The MongoDB Atlas public key for API access. |
| `MONGODB_ATLAS_PRIVATE_KEY`           | The MongoDB Atlas private key for API access. |
| `TF_VAR_mongo_organization_id`        | The ID of the MongoDB Atlas organization. |
| `TF_VAR_mongo_db_username`            | The desired name of the user that will be created to interact with the MongoDB Atlas database. |
| `TF_VAR_github_personal_access_token` | Lorem_ipsum |
| `TF_VAR_jwt_secret_key`               | Lorem_ipsum |
| `TF_VAR_mongo_db_password`            | The desired password of the user that will be created to interact with the MongoDB Atlas database. |

## MongoDB Atlas
The application requires a MongoDB connection to work. To keep things extra cloudy, here's a guide to using the free
offering from [MongoDB Atlas](https://www.mongodb.com/atlas/database).
1. Create a new account.
2. Obtain Organization ID from Organization Settings.
    - Set `mongo_organization_id` to this value.
3. Generate API Key:
    - Set `MONGODB_ATLAS_PUBLIC_KEY` to public key.
    - Set `MONGODB_ATLAS_PRIVATE_KEY` to private key.
4. Define a database user to manage the resources. Set `TF_VAR_mongo_db_password` and `TF_VAR_mongo_db_password` to whatever you want.

### Picking a region {#id-1}
If you want everything to be free, use the M0 shared cluster as covered here:

https://docs.atlas.mongodb.com/reference/amazon-aws/

## AWS
First, you'll want to create a new IAM account with proper permissions and get the Access Key and Secert Key they present you on user creation. For example, I made a `terraform` user with full Admin privilges just for this. Set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` accordingly.

### Picking a region {#id-2}
Set `aws_region` to your desired region. It needs to support all the resources we're going to deploy.

Most importantly, the self-signed SSL certificate we generate is tied to region. Update the Common Name (CN) in `ssl/ssl.conf` appropriately if you change the region from `us-west-1`.

## GitHub
This project assumes source code resides in public GitHub repos. Follow their [guide](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token_ ) to create yourself a personal access token. Set `TF_VAR_github_personal_access_token` to this value.

## JWT
The Flask backend for `HomeInventoryPy` uses `flask-jwt-extended` for secure authentication and requires a key for encryption. Set `TF_VAR_jwt_secret_key` per the recommendations given by [flask-jwt-extended docs](https://flask-jwt-extended.readthedocs.io/). 


# Usage
Generate the SSL files:

    pushd ssl
    ./generate_cert.sh
    popd

Put your secrets in your shell environment:

    . secrets.sh

Test you did everything correctly. Fix any errors until you're happy with the report:

    terraform plan

Do it and wait the :

    terraform apply

Go to the created `CodePipeline` project in AWS and confirm the CodeStarConnection in the CodePipeline service. Under Source, keep editing until you get to Update Pending Connection. Follow the prompts.

Go to the created `AWS Amplify` application and navigate to the HomeInventoryPy webpage. Open the browser's console (Right Click, Inspect, Console tab). Follow the instructions of the first note about accepting security risk. See [note](id-3) below for why.

When done:

    terraform destroy

# Architecture
`home-inventory-py-backend` is a Flask application hosting a REST API requiring a MongoDB database to persist data. Thus, `MongoDB Atlas` free database is created and connected to the backend.
A `CodeBuild` project is used to connect the GitHub repo for `home-inventory-py-backend` to AWS. It runs the simple "build" process for the backend: creating a zip of the project. That's because where it's deployed, `Elastic Beanstalk`, likes to take in zip files as input.
To connect the `CodeBuild` build process to the final `Elastic Beanstalk` deployment, a `CodePipeline` project is created and ties these together.
`home-inventory-py-frontend`, the React frontend that was written to interact with the backend, lives in another GitHub repo. `AWS Amplify` is used to handle everything about bringing that code to AWS and deploying it.

## CodeStar Connection
By AWS design, this connection is created in the Pending state and must be manually accepted. Oh well...

## SSL {#id-3}
The `ssl` folder contains stuff to generate a self-signed SSL certificate. This is BAD practice in almost every scenarion, except the prototype proof-of-concept that this project is. But I refuse to pay money for a real certificate.

`AWS Amplify` only deploys to HTTPS websites, so there were cert errors trying to connect to the HTTP-hosted backed. `Elastic Beanstalk` can do both HTTP and HTTPS, so I set up HTTPS to terminate at the [load balancer](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/configuring-https.html).

However, the cert used is self-signed. Browsers will warn users and not let them in unless they manually accept the risk. That's okay for a prototype project, but it's the backend that needs the acceptance which the user never sees normally. So I updated my frontend project to print the backend URL in the console. User clicks, accepts the risks, reloads the Amplify webpage, and everything works forever!!