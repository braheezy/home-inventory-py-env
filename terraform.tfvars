# These variables can customize most things about the project.
/*
        AWS 
*/
# IMPORTANT: If the aws_region changes, update ssl/ssl.conf accordingly.
aws_region                              = "us-west-1"
aws_iam_role_name                       = "HomeInventory-EnvBuilder"
aws_s3_bucket_name                      = "home-inventory-py-artifacts"
aws_codebuild_project_name              = "HomeInventoryPy-Build"
aws_elastic_beanstalk_application_name  = "HomeInvPy-API"
aws_codestarconnections_connection_name = "HomeInventoryPy-Connection"
aws_codepipeline_name                   = "HomeInventoryPy-Pipeline"
aws_amplify_app_name                    = "HomeInventoryPy-Frontend"
# Github location of Flask backend project.
aws_codepipeline_source_repo = "mbraha/home-inventory-py-backend"
# Github location of Node frontend project.
aws_amplify_repo_url = "https://github.com/mbraha/home-inventory-py-frontend"

/*
        MONGODB 
*/
mongo_project_name    = "HomeInventoryPy"
mongo_cluster_name    = "Cluster-0"
mongo_organization_id = "616c7dd7f3c14966f5dcfbd8"
# Set `mongo_db_username` in secrets.sh. 
mongo_db_username = "admin"
# This can be wherever M0 is supported. See https://docs.atlas.mongodb.com/reference/amazon-aws/
mongo_cluster_region = "US_WEST_2"
