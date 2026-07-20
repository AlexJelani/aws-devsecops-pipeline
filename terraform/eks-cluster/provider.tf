provider "aws" {
  region = var.region
}

terraform {
  cloud {
    organization = "alexander-tech-inc"

    workspaces {
      name = "dsb-aws-devsecops-eks-cluster"
    }
  }
}