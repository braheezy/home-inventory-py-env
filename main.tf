terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "1.1.1"
    }
  }
}
/*
    PROVIDERS
*/
# Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in the environment
provider "aws" {
  region = var.aws_region
}

# Set MONGODB_ATLAS_PUBLIC_KEY and MONGODB_ATLAS_PRIVATE_KEY in the environment
provider "mongodbatlas" {
}
/*
            GENERAL RESOURCES
*/
variable "github_personal_access_token" {
  type      = string
  sensitive = true
}
variable "aws_region" {
  type = string
}
variable "aws_iam_role_name" {
  type = string
}
variable "aws_s3_bucket_name" {
  type = string
}

# Use data sources to obtain the AWS Managed policy.
data "aws_iam_policy" "CodeBuildAdmin" {
  arn = "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess"
}
data "aws_iam_policy" "CloudWatchLogs" {
  arn = "arn:aws:iam::aws:policy/AWSOpsWorksCloudWatchLogs"
}
data "aws_iam_policy" "ElasticBeanstalkAdmin" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk"
}

# Setup the singular role for this entire deployment.
resource "aws_iam_role" "default" {
  name = var.aws_iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["codebuild.amazonaws.com",
            "codepipeline.amazonaws.com",
            "elasticbeanstalk.amazonaws.com",
          "s3.amazonaws.com"]
        }
      }
    ]
  })
}
# Attach AWS managed policies to our role.
resource "aws_iam_role_policy_attachment" "CodeBuildAdmin" {
  role       = aws_iam_role.default.name
  policy_arn = data.aws_iam_policy.CodeBuildAdmin.arn
}
resource "aws_iam_role_policy_attachment" "CloudWatchLogs" {
  role       = aws_iam_role.default.name
  policy_arn = data.aws_iam_policy.CloudWatchLogs.arn
}
resource "aws_iam_role_policy_attachment" "ElasticBeanstalkAdmin" {
  role       = aws_iam_role.default.name
  policy_arn = data.aws_iam_policy.ElasticBeanstalkAdmin.arn
}
# The storage location for artifacts.
resource "aws_s3_bucket" "default" {
  bucket = var.aws_s3_bucket_name
  acl    = "private"
  # So the bucket is remove during destroy operations.
  force_destroy = true
}
# Create a custom policy for S3 access and attach to role.
resource "aws_iam_role_policy" "S3" {
  role = aws_iam_role.default.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:*"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.default.arn}", "${aws_s3_bucket.default.arn}/*"]
      }
    ]
  })
}
/*
            MONGODB ATLAS RESOURCES
*/
variable "mongo_organization_id" {
  type = string
}
variable "mongo_db_username" {
  type = string
}
variable "mongo_db_password" {
  type      = string
  sensitive = true
}
variable "mongo_project_name" {
  type = string
}
variable "mongo_cluster_name" {
  type = string
}
variable "mongo_cluster_region" {
  type = string
}

resource "mongodbatlas_project" "default" {
  name   = var.mongo_project_name
  org_id = var.mongo_organization_id
}
resource "mongodbatlas_database_user" "default" {
  username   = var.mongo_db_username
  password   = var.mongo_db_password
  project_id = mongodbatlas_project.default.id

  auth_database_name = "admin"
  roles {
    role_name     = "atlasAdmin"
    database_name = "admin"
  }
}
resource "mongodbatlas_cluster" "default" {
  name       = var.mongo_cluster_name
  project_id = mongodbatlas_project.default.id

  provider_name               = "TENANT"
  backing_provider_name       = "AWS"
  provider_instance_size_name = "M0"
  provider_region_name        = var.mongo_cluster_region

  cluster_type = "REPLICASET"
}
resource "mongodbatlas_project_ip_access_list" "default" {
  project_id = mongodbatlas_project.default.id
  cidr_block = "0.0.0.0/0"
  comment    = "That's right, everyone can access."
}
/*
            CODEBUILD RESOURCES
*/
variable "aws_codebuild_project_name" {
  type = string
}

# Setup credentials to source control repo.
resource "aws_codebuild_source_credential" "default" {
  server_type = "GITHUB"
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  token       = var.github_personal_access_token
}
resource "aws_codebuild_project" "default" {
  name         = var.aws_codebuild_project_name
  service_role = aws_iam_role.default.arn

  environment {
    type         = "LINUX_CONTAINER"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    compute_type = "BUILD_GENERAL1_SMALL"
  }

  source {
    type = "CODEPIPELINE"
  }

  artifacts {
    type = "CODEPIPELINE"
  }
}

/*
            ELASTIC BEANSTALK RESOURCES
*/
variable "jwt_secret_key" {
  type      = string
  sensitive = true
}
variable "aws_elastic_beanstalk_application_name" {
  type = string
}

resource "aws_iam_server_certificate" "default" {
  name_prefix      = "home-inventory-eb-x509-"
  certificate_body = file("ssl/public.crt")
  private_key      = file("ssl/privatekey.pem")

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_elastic_beanstalk_application" "default" {
  name = var.aws_elastic_beanstalk_application_name
}
resource "aws_elastic_beanstalk_environment" "default" {
  name                = "${aws_elastic_beanstalk_application.default.name}-env"
  application         = aws_elastic_beanstalk_application.default.name
  solution_stack_name = "64bit Amazon Linux 2 v3.3.7 running Python 3.7"

  # This is required, or the following error: "Environment must have instance profile associated with it"
  # The value seems to be a default.
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

  # Set environment variables.
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "JWT_SECRET_KEY"
    value     = var.jwt_secret_key
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "MONGO_PASSWORD"
    value     = var.mongo_db_password
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "MONGO_USERNAME"
    value     = var.mongo_db_username
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "MONGO_CONNECTION_STRING"
    value     = regex("\\/\\/(.*)", mongodbatlas_cluster.default.connection_strings[0].standard_srv)[0]
  }

  # Configure Load Balancer for HTTPS using a self-signed cert I already uploaded manually.
  # https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html#command-options-general-elbloadbalancer
  setting {
    namespace = "aws:elb:listener:443"
    name      = "ListenerProtocol"
    value     = "HTTPS"
  }
  # Fixed a sticky bug like described here: https://stackoverflow.com/questions/51101050/408-http-errors-trying-to-access-https-on-aws-elastic-beanstalk-with-load-balanc
  setting {
    namespace = "aws:elb:listener:443"
    name      = "InstancePort"
    value     = "80"
  }
  setting {
    namespace = "aws:elb:listener:443"
    # See on how this cert was made and uploaded: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/configuring-https-ssl.html
    name  = "SSLCertificateId"
    value = aws_iam_server_certificate.default.arn
  }
}
/*
            CODEPIPELINE RESOURCES
*/
variable "aws_codestarconnections_connection_name" {
  type = string
}
variable "aws_codepipeline_name" {
  type = string
}
variable "aws_codepipeline_source_repo" {
  type = string
}
# Remember to accept the Pending connection in CodePipeline!!
resource "aws_codestarconnections_connection" "default" {
  name          = var.aws_codestarconnections_connection_name
  provider_type = "GitHub"
}
# Create a custom policy for CodeStar Connections and attach to role.
resource "aws_iam_role_policy" "CodeStarConnections" {
  role = aws_iam_role.default.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["codestar-connections:*"]
        Effect   = "Allow"
        Resource = ["${aws_codestarconnections_connection.default.arn}"]
      }
    ]
  })
}
resource "aws_codepipeline" "default" {
  name     = var.aws_codepipeline_name
  role_arn = aws_iam_role.default.arn

  artifact_store {
    location = aws_s3_bucket.default.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.default.arn
        FullRepositoryId = var.aws_codepipeline_source_repo
        BranchName       = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.default.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName = aws_elastic_beanstalk_application.default.name
        EnvironmentName = aws_elastic_beanstalk_environment.default.name
      }
    }
  }
}
/*
            AWS AMPLIFY RESOURCES
*/
variable "aws_amplify_app_name" {
  type = string
}
variable "aws_amplify_repo_url" {
  type = string
}

resource "aws_amplify_branch" "master" {
  app_id      = aws_amplify_app.default.id
  branch_name = "master"
  framework   = "Webpack"
  stage       = "PRODUCTION"
}
resource "aws_amplify_app" "default" {
  name         = var.aws_amplify_app_name
  repository   = var.aws_amplify_repo_url
  access_token = var.github_personal_access_token

  enable_branch_auto_build = true
  # Auto-generated from AWS Amplify, presumably default Node stuff.
  build_spec = <<-SPEC
        version: 1
        frontend:
          phases:
            preBuild:
              commands:
                - npm ci
            build:
              commands:
                - npm run build
          artifacts:
            baseDirectory: ./dist
            files:
              - '**/*'
          cache:
            paths:
              - node_modules/**/*
        SPEC
  # The default rewrites and redirects added by the Amplify Console.
  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }
  environment_variables = {
    API_URL = "https://${aws_elastic_beanstalk_environment.default.cname}"
  }

}
# STOLEN: https://github.com/masterpointio/terraform-aws-amplify-app/blob/master/main.tf#L180
resource "aws_amplify_webhook" "master" {
  app_id      = aws_amplify_app.default.id
  branch_name = aws_amplify_branch.master.branch_name
  description = "trigger-master"

  # NOTE: We trigger the webhook via local-exec so as to kick off the first build on creation of Amplify App.
  provisioner "local-exec" {
    command = "curl -X POST -d {} '${aws_amplify_webhook.master.url}&operation=startbuild' -H 'Content-Type:application/json'"
  }
}
