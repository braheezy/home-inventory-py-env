# Purpose
At the press of a "button", the AWS resources to host `HomeInventoryPy` are created. 

# Usage
First, the following variables are required. Set them in `terraform.tfvars`.

| Variable                                  | Description |
| ----------------------------------------- | ----------------------------------------- |
| `mongo_organization_id`                   | The ID of the MongoDB Atlas organization. |
| `mongo_public_key`                        | The MongoDB Atlas public key for API access. |
| `mongo_private_key`                       | The MongoDB Atlas private key for API access. |
| `mongo_db_username`                       | The desired name of the user that will be created to interact with the MongoDB Atlas database. |
| `mongo_db_password`                       | The desired password of the user that will be created to interact with the MongoDB Atlas database. |
| `aws_region`                              | Lorem ipsum |
| `aws_iam_role_name`                       | Lorem ipsum |
| `aws_s3_bucket_name`                      | Lorem ipsum |
| `aws_codebuild_project_name`              | Lorem ipsum |
| `aws_elastic_beanstalk_application_name`  | Lorem ipsum |
| `aws_codestarconnections_connection_name` | Lorem ipsum |
| `aws_codepipeline_name`                   | Lorem ipsum |
| `aws_amplify_app_name`                    | Lorem ipsum |
| `aws_codepipeline_source_repo`            | Lorem ipsum |
| `aws_amplify_repo_url`                    | Lorem ipsum |

Next, the following are sensitive variables. Set them in `secrets.sh`.

| Variable                              | Description |
| ------------------------------------- | ------------------------------------- |
| `AWS_ACCESS_KEY_ID`                   | The ID of the MongoDB Atlas organization. |
| `AWS_SECRET_ACCESS_KEY`               | The MongoDB Atlas public key for API access. |
| `MONGODB_ATLAS_PUBLIC_KEY`            | The MongoDB Atlas private key for API access. |
| `MONGODB_ATLAS_PRIVATE_KEY`           | The desired name of the user that will be created to interact with the MongoDB Atlas database. |
| `TF_VAR_github_personal_access_token` | The desired password of the user that will be created to interact with the MongoDB Atlas database. |
| `TF_VAR_jwt_secret_key`               | Lorem ipsum |
| `TF_VAR_mongo_db_password`            | Lorem ipsum |

Finally, run `launch.sh`.

# MongoDB Atlas
The application requires a MongoDB connection to work. To keep things extra cloudy, here's a guide to using the free
offering from MongoDB. (LINK)
1. Create a new account with MongoDB Atlas.
2. Obtain Organization ID from Organization Settings. Set `mongo_organization_id` to this value.
3. Generate API Key:
- Navigate Organization Settings -> Access Manager -> API Keys.
- New key with "Organization Owner" permissions.
- Set `mongo_public_key` to public key.
- Set `mongo_private_key` to private key.