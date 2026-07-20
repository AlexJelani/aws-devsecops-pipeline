provider "aws" {
  region     = var.region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

terraform {
  cloud {
    organization = "alexander-tech-inc"

    workspaces {
      name = "dsb-aws-devsecops-eks-cluster"
    }
  }
}