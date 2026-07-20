variable "resource_prefix" {
  type        = string
  description = "Prefix for AWS Resources"
  default     = "dsb"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS Cluster"
  default     = "dsb-devsecops-cluster"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  type        = string
  description = "AWS access key ID for Terraform Cloud runs"
  default     = ""
}

variable "aws_secret_access_key" {
  type        = string
  description = "AWS secret access key for Terraform Cloud runs"
  default     = ""
}

variable "aws_profile" {
  type        = string
  description = "AWS shared config profile name for Terraform Cloud runs"
  default     = ""
}

variable "SNYK_TOKEN" {}
variable "SNYK_ORG_ID" {}

variable "eks_admin_iam_username" {
  type        = string
  description = "IAM username to grant cluster-admin access"
  default     = "iamadmin-dev"
}

variable "github_username" {
  type        = string
  description = "GitHub username or organization that owns the awsome-fastapi repository"
  default     = "AlexJelani"
}