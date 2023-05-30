# Configure the AWS Provider
provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Terraform   = "true"
      Environment = var.project_environment
    }
  }
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_default_tags" "current" {}

locals {
  name       = var.project_name
  region     = var.project_region
  account_id = data.aws_caller_identity.current.account_id

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  eks_cluster_iam_role_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  eks_managed_node_group_iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  eks_fargate_profile_iam_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}
