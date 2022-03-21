terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

  }
}
provider "github" {
  token = "${ TOKEN }"
}
# Configure the AWS Provider
provider "aws" {
  region                  = "${var.region}"
  shared_credentials_file = "${var.shared_credentials}"
  profile                 = "${var.profile}"
  //alias = "primary"
}

// module "consul" {
//   source = "git@github.com:Ars-Rem/aws_cicd_test.git"
// }

// module "consul" {
//   source = "s3::https://s3-eu-west-1.amazonaws.com/examplecorp-terraform-modules/vpc.zip"
// }
