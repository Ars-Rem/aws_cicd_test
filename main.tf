#data block
#data buildspec  
data "local_file" "buildspec" {
  filename = "buildspec.yml.tmpl"
}

module "iam_group_with_policies" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "~> 4"

  name = var.iam_group

  group_users = [
    "${var.user}"
  ]

  attach_iam_self_management_policy = true

  custom_group_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess",
    "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess",
    "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess",
    "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess",
    "arn:aws:iam::aws:policy/AWSCodeStarFullAccess",
    "arn:aws:iam::aws:policy/IAMReadOnlyAccess",
    "arn:aws:iam::aws:policy/IAMSelfManageServiceSpecificCredentials",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]
}

resource "aws_iam_user" "user" {
  name = var.user
  path = "/"
}

resource "aws_iam_access_key" "user" {
  user = aws_iam_user.user.name
}

resource "aws_iam_role" "codepipeline_role" {
  name = var.name_codepipeline_role

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": [
        
       "sts:AssumeRole"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObjectAcl",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codestar-connections:UseConnection"
      ],
      "Resource": "${aws_codestarconnections_connection.example.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
  "Effect": "Allow",
  "Resource": [
      "arn:aws:s3:::to-project-${var.owner}/*",
      "arn:aws:s3:::codepipeline-us-west-1-*",
      "arn:aws:iam::175016064603:role/aws_iam_role_to_project"
  ],
  "Action": [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
 }

  ]
}
EOF
}
#arn:aws:s3:::codepipeline-us-west-1-*
// resource "aws_codecommit_repository" "repository" {
//   repository_name = "html"
//   description     = "This is the Sample"
//   default_branch = "main"
// }

// module "vpc" {
//   source = "terraform-aws-modules/vpc/aws"

//   name = "my-vpc"
//   cidr = var.vpc_cidr_block

//   azs             = ["${var.region}a", "${var.region}b"]
//   private_subnets = ["${var.privet_subnet_1}", "${var.privet_subnet_2}"]
//   public_subnets  = ["${var.public_subnet_1}", "${var.public_subnet_2}"]

//   enable_nat_gateway = false
//   enable_vpn_gateway = false

//   tags = {
//     Terraform   = "true"
//     Environment = "dev"
//   }
// }


# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr_block

  // tags = {
  //   Owner = "${var.owner}"
  //   Name  = "${var.owner}"
  // }
}

# Create a availability_zones
data "aws_availability_zones" "az" {

  all_availability_zones = true
  exclude_names          = ["ua-east-2a", "ua-east-2b", "ua-east-2c"]

  filter {
    name   = "opt-in-status"
    values = ["not-opted-in", "opted-in"]
  }
}
# Create a subnet
resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.sbn_cidr_block_public
  map_public_ip_on_launch = true

  tags = {
    Owner = var.owner
    Name  = var.owner
  }
}
resource "aws_subnet" "subnet_privet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.sbn_cidr_block_privet
  map_public_ip_on_launch = false

  tags = {
    Owner = var.owner
    Name  = var.owner
  }
}

# Create security_group
resource "aws_security_group" "sg" {
  name        = "${var.owner}-sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress = [{
    description      = "All traffic"
    protocol         = var.sg_ingress_proto
    from_port        = var.sg_ingress_ssh
    to_port          = var.sg_ingress_http
    cidr_blocks      = [var.sg_ingress_cidr_block]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false

  }]

  egress = [{
    description      = "All traffic"
    protocol         = var.sg_egress_proto
    from_port        = var.sg_egress_all
    to_port          = var.sg_egress_all
    cidr_blocks      = [var.sg_egress_cidr_block]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false

  }]

  tags = {
    Owner = var.owner
    Name  = var.owner

  }
}


resource "aws_kms_key" "s3kmskey" {
  description                        = "s3bkmskey-${var.owner}-${var.user}"
  deletion_window_in_days            = 7
  bypass_policy_lockout_safety_check = false
  is_enabled                         = true
  multi_region                       = true
  policy                             = <<EOF
  {
    "Id": "key-consolepolicy-3",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                  "arn:aws:iam::${var.owner}:root",
                  "arn:aws:iam::${var.owner}:role/aws_iam_role_to_project",
                  "arn:aws:iam::175016064603:user/${var.user}"
                ]
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow access for Key Administrators",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.owner}:role/${var.name_codepipeline_role}",
                    "arn:aws:iam::${var.owner}:user/${var.user}",
                    "arn:aws:iam::${var.owner}:role/aws_iam_role_to_project"
                ]
            },
            "Action": [
                "kms:Create*",
                "kms:Describe*",
                "kms:Enable*",
                "kms:List*",
                "kms:Put*",
                "kms:Update*",
                "kms:Revoke*",
                "kms:Disable*",
                "kms:Get*",
                "kms:Delete*",
                "kms:TagResource",
                "kms:UntagResource",
                "kms:ScheduleKeyDeletion",
                "kms:CancelKeyDeletion"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow use of the key",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.owner}:role/${var.name_codepipeline_role}",
                    "arn:aws:iam::${var.owner}:user/${var.user}",
                    "arn:aws:iam::${var.owner}:role/aws_iam_role_to_project"
                ]
            },
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow attachment of persistent resources",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.owner}:role/${var.name_codepipeline_role}",
                    "arn:aws:iam::${var.owner}:user/${var.user}",
                    "arn:aws:iam::${var.owner}:role/aws_iam_role_to_project"
                ]
            },
            "Action": [
                "kms:CreateGrant",
                "kms:ListGrants",
                "kms:RevokeGrant"
            ],
            "Resource": "*",
            "Condition": {
                "Bool": {
                    "kms:GrantIsForAWSResource": "true"
                }
            }
        }
    ]
}

  EOF
}


resource "aws_kms_alias" "s3kmskey" {
  name          = "alias/${var.alias_name}-${var.owner}-${var.user}"
  target_key_id = aws_kms_key.s3kmskey.id

}

resource "aws_codestarconnections_connection" "example" {
  name          = "connect_to_GitHub_repo_html"
  provider_type = "GitHub"
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = "deploy-bucket-${var.owner}"
  force_destroy = true
}


resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.codepipeline_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3kmskey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}


resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.to-project.id


  policy = <<EOF
  {
	"Version": "2012-10-17",
	"Statement": [
		 {
     "Sid": "PublicReadGetObject",
     "Effect": "Allow",
     "Principal": "*",
     "Action": "s3:GetObject",
    
     "Resource": "arn:aws:s3:::to-project-${var.owner}/**"
 }
	]
}
EOF
}
# "Action": "s3:GetObject",
#create project##########################################################################################################################
resource "aws_s3_bucket" "to-project" {
  bucket        = "to-project-${var.owner}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "to-project" {
  bucket = aws_s3_bucket.to-project.id
  acl    = "private"

}

resource "aws_iam_role" "to-project" {
  name = "aws_iam_role_to_project"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "to-project" {
  role = aws_iam_role.to-project.name

  policy = <<EOF
{
  "Version": "2012-10-17",
      "Statement": [
        {
      "Sid": "CodeBuildDefaultPolicy",
      "Effect": "Allow",
      "Action": [
        "codebuild:*",
        "iam:${var.user}"
      ],
      "Resource": "*"      
    },
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": [
        "arn:aws:ec2:${var.region}:${var.owner}:network-interface/*"
      ],
      "Condition": {
        "StringLike": {
          "ec2:Subnet": [
            
            "arn:aws:ec2:${var.region}:${var.owner}:subnet/*"
          ],
          "ec2:AuthorizedService": "codebuild.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.to-project.arn}",
        "${aws_s3_bucket.to-project.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
        ],
        "Resource": [
            "arn:aws:s3:::deploy-bucket-175016064603/*",
            "arn:aws:s3:::to-project-175016064603/*"
          ]
    }
  ]
}

EOF
}

resource "aws_codebuild_project" "example" {
  name          = "angular-project"
  description   = "test_codebuild_project"
  build_timeout = "5"
  service_role  = aws_iam_role.to-project.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  // cache {
  //   type     = "S3"
  //   location = aws_s3_bucket.to-project.bucket
  // }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    // environment_variable {
    //   name  = "SOME_KEY1"
    //   value = "SOME_VALUE1"
    // }

    // environment_variable {
    //   name  = "SOME_KEY2"
    //   value = "SOME_VALUE2"
    //   type  = "PARAMETER_STORE"
    // }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }

    s3_logs {
      status   = "DISABLED"
      
      //"${aws_s3_bucket.to-project.id}/build-log"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.repo_owner}/${var.repo_name}.git"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
    buildspec = data.local_file.buildspec.content

  }

  source_version = "main"

  // vpc_config {
  //   vpc_id = aws_vpc.vpc.id

  //   subnets = [
  //     aws_subnet.subnet_public.id,
  //     aws_subnet.subnet_privet.id,
  //   ]

  //   security_group_ids = [
  //     aws_security_group.sg.id,
  //     aws_security_group.sg.id,
  //   ]
  // }

  // tags = {
  //   Environment = "Test"
  // }
}

// resource "aws_codebuild_project" "project-with-cache" {
//   name           = "test-project-cache"
//   description    = "test_codebuild_project_cache"
//   build_timeout  = "5"
//   queued_timeout = "5"

//   service_role = aws_iam_role.to-project.arn

//   artifacts {
//     type = "NO_ARTIFACTS"
//   }

//   cache {
//     type  = "LOCAL"
//     modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
//   }

//   environment {
//     compute_type                = "BUILD_GENERAL1_SMALL"
//     image                       = "aws/codebuild/standard:1.0"
//     type                        = "LINUX_CONTAINER"
//     image_pull_credentials_type = "CODEBUILD"

//     environment_variable {
//       name  = "SOME_KEY1"
//       value = "SOME_VALUE1"
//     }
//   }

//   source {
//     type            = "GITHUB"
//     location        = "https://github.com/${var.repo_owner}/${var.repo_name}.git"
//     git_clone_depth = 1
//   }

//   tags = {
//     Environment = "Test"
//   }
// }
// #end create project######################################################################################################################
resource "aws_codepipeline" "codepipeline" {
  name     = "${var.aws_codepipeline_name}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_alias.s3kmskey.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      run_order        = "1"
      output_artifacts = ["source_input"]
      namespace        = "SourceVariables"

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.example.arn
        FullRepositoryId = "${var.repo_owner}/${var.repo_name}"
        BranchName       = "main"
        //OutputArtifactFormat = "CODEBUILD_CLONE_REF"
        //PollForSourceChanges  = false
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
      input_artifacts  = ["source_input"]
      output_artifacts = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = "angular-project"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["source_output"]
      version         = "1"


      configuration = {
        Extract    = "true"
        BucketName = "to-project-${var.owner}"
      }
    }
  }
}
