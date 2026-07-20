variable "resource_prefix" {
  type        = string
  description = "Prefix for AWS Resources"
  default     = "dsb"
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