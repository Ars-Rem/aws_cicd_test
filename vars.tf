variable "owner" {
  description = "owner"
  type        = string
  default     = "175016064603"
}
variable "region" {
  description = "region"
  type        = string
  default     = "us-west-1"
}
variable "shared_credentials" {
  description = "shared_credentials_file"
  type        = string
  default     = "~/.aws/credentials"
}
variable "user" {
  description = "user"
  type        = string
  default     = "CI-User"
}
variable "profile" {
  description = "profile"
  type        = string
  default     = "default"
}
variable "iam_group" {
  description = "iam_group"
  type        = string
  default     = "CI_Account"
}

# Variables for VPC
variable "vpc_cidr_block" {
  description = "CIDR block VPC"
  type        = string
  default     = "172.16.0.0/16"
}

#Variable for public subnets
variable "public_subnet_1" {
  description = "CIDR subnet"
  type        = string
  default     = "172.16.1.0/24"
}
variable "public_subnet_2" {
  description = "CIDR subnet"
  type        = string
  default     = "172.16.2.0/24"
}
#Variable for privet subnets
variable "privet_subnet_1" {
  description = "CIDR subnet"
  type        = string
  default     = "172.16.101.0/24"
}
variable "privet_subnet_2" {
  description = "CIDR subnet"
  type        = string
  default     = "172.16.102.0/24"
}

variable "provider_git" {
  default = "GitHubEnterpriseServer"
}

variable "keys" {
  default = {
    key1 = "value1"
    key2 = "value2"
  }
  type = map(string)
}

variable "repo_owner" {
  default = "Ars-Rem"
}
variable "repo_name" {
  default = "html"
}

variable "alias_name" {
  type    = string
  default = "s3bkmskey"
}

variable "name_codepipeline_role" {
  type = string
  default = "role_to_pipeline"
}
// variable "dockerhub_credentionals" {
//   type = string
// }
// variable "codestar_connector_credentionals" {
//   type = string
// }
