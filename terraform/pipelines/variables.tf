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