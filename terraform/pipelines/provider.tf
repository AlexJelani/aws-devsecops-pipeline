provider "aws" {
  region = var.region
}

provider "random" {}

terraform {
  cloud {
    organization = "alexander-tech-inc"

    workspaces {
      name = "dsb-aws-devsecops-pipelines"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}