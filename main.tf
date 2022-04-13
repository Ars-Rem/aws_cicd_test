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
    "arn:aws:iam::aws:policy/IAMSelfManageServiceSpecificCredentials"
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
  name = "${var.name_codepipeline_role}"

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
    }
  ]
}
EOF
}

// resource "aws_codecommit_repository" "repository" {
//   repository_name = "html"
//   description     = "This is the Sample"
//   default_branch = "main"
// }

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = var.vpc_cidr_block

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["${var.privet_subnet_1}", "${var.privet_subnet_2}"]
  public_subnets  = ["${var.public_subnet_1}", "${var.public_subnet_2}"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
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
                "AWS": "arn:aws:iam::${var.owner}:root"
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
                    "arn:aws:iam::${var.owner}:user/${var.user}"
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
                    "arn:aws:iam::${var.owner}:user/${var.user}"
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
                    "arn:aws:iam::${var.owner}:user/${var.user}"
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
  bucket = "deploy-bucket-${var.owner}"
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
resource "aws_codepipeline" "codepipeline" {
  name     = "deploy_html_to_s3"
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
      run_order = "1"
      output_artifacts = ["SourceArtifact"]
      namespace        = "SourceVariables"
         
      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.example.arn
        FullRepositoryId     = "${var.repo_owner}/${var.repo_name}"
        BranchName           = "main"
        //OutputArtifactFormat = "CODEBUILD_CLONE_REF"
        //PollForSourceChanges  = false
      }
    }
  }

  // stage {
  //   name = "Build"

  //   action {
  //     name             = "Build"
  //     category         = "Build"
  //     owner            = "AWS"
  //     provider         = "CodeBuild"
  //     input_artifacts  = ["source_output"]
  //     output_artifacts = ["SourceArtifact"]
  //     version          = "1"

  //     configuration = {
  //       ProjectName = "test"
  //     }
  //   }
  // }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["SourceArtifact"]
      version         = "1"


      configuration = {
        Extract    = "true"
        BucketName = "deployment-bucket-${var.owner}"
      }
    }
  }
}

##########################################################################################################



// #179 genkey
// resource "aws_codepipeline" "codepipeline" {
//   name     = "tf-test-pipeline"
//   role_arn = aws_iam_role.codepipeline_role.arn

//   artifact_store {
//     location = aws_s3_bucket.codepipeline_bucket.bucket
//     type     = "S3"

//     encryption_key {
//       id   = data.aws_kms_alias.s3kmskey.arn
//       type = "KMS"
//     }
//   }

//   stage {
//     name = "Source"

//     action {
//       name             = "Source"
//       category         = "Source"
//       owner            = "AWS"
//       provider         = "CodeStarSourceConnection"
//       version          = "1"
//       output_artifacts = ["source_output"]
//       run_order = "1"
//       namespace        = "SourceVariables"

//       configuration = {
//         ConnectionArn    = aws_codestarconnections_connection.example.arn
//         FullRepositoryId = "${var.repo_owner}/${var.repo_name}"
//         BranchName       = "main"
//       }
//     }
//   }

//   stage {
//     name = "Build"

//     action {
//       name             = "Build"
//       category         = "Build"
//       owner            = "AWS"
//       provider         = "CodeBuild"
//       input_artifacts  = ["source_output"]
//       output_artifacts = ["build_output"]
//       version          = "1"

//       configuration = {
//         ProjectName = "test"
//       }
//     }
//   }

//   stage {
//     name = "Deploy"

//     action {
//       name            = "Deploy"
//       category        = "Deploy"
//       owner           = "AWS"
//       provider        = "CloudFormation"
//       input_artifacts = ["build_output"]
//       version         = "1"

//       configuration = {
//         ActionMode     = "REPLACE_ON_FAILURE"
//         Capabilities   = "CAPABILITY_AUTO_EXPAND,CAPABILITY_IAM"
//         OutputFileName = "CreateStackOutput.json"
//         StackName      = "MyStack"
//         TemplatePath   = "build_output::sam-templated.yaml"
//       }
//     }
//   }
// }

// resource "aws_codestarconnections_connection" "example" {
//   name          = "example-connection"
//   provider_type = "GitHub"
// }

// resource "aws_s3_bucket" "codepipeline_bucket" {
//   bucket = "test-bucket-${var.owner}"
// }

// resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
//   bucket = aws_s3_bucket.codepipeline_bucket.id
//   acl    = "private"
// }

// resource "aws_iam_role" "codepipeline_role" {
//   name = "${var.name_codepipeline_role}"

//   assume_role_policy = <<EOF
// {
//   "Version": "2012-10-17",
//   "Statement": [
//     {
//       "Effect": "Allow",
//       "Principal": {
//         "Service": "codepipeline.amazonaws.com"
//       },
//       "Action": "sts:AssumeRole"
//     }
//   ]
// }
// EOF
// }

// resource "aws_iam_role_policy" "codepipeline_policy" {
//   name = "codepipeline_policy"
//   role = aws_iam_role.codepipeline_role.id

//   policy = <<EOF
// {
//   "Version": "2012-10-17",
//   "Statement": [
//     {
//       "Effect":"Allow",
//       "Action": [
//         "s3:GetObject",
//         "s3:GetObjectVersion",
//         "s3:GetBucketVersioning",
//         "s3:PutObjectAcl",
//         "s3:PutObject"
//       ],
//       "Resource": [
//         "${aws_s3_bucket.codepipeline_bucket.arn}",
//         "${aws_s3_bucket.codepipeline_bucket.arn}/*"
//       ]
//     },
//     {
//       "Effect": "Allow",
//       "Action": [
//         "codestar-connections:UseConnection"
//       ],
//       "Resource": "${aws_codestarconnections_connection.example.arn}"
//     },
//     {
//       "Effect": "Allow",
//       "Action": [
//         "codebuild:BatchGetBuilds",
//         "codebuild:StartBuild"
//       ],
//       "Resource": "*"
//     }
//   ]
// }
// EOF
// }

// data "aws_kms_alias" "s3kmskey" {
//   name = "alias/myKmsKey005"
// }
