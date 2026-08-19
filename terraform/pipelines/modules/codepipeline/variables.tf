variable "repo_name" {
  description = "Name of the GitHub Repository"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket for pipeline artifacts"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 ARN for pipeline artifacts"
  type        = string
}

variable "github_connection_arn" {
  description = "CodeStar connection ARN for GitHub"
  type        = string
}

variable "repository_id" {
  description = "GitHub repository ID"
  type        = string
}

variable "branch_name" {
  description = "Branch name to pull code from"
  type        = string
}

# CodeBuild Variables
variable "compute_type" {
  description = "Compute type for CodeBuild"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_image" {
  description = "Docker image for the CodeBuild environment"
  type        = string
  default     = "aws/codebuild/standard:5.0"
}

variable "environment_type" {
  description = "Type of CodeBuild environment"
  type        = string
  default     = "LINUX_CONTAINER"
}

variable "privileged_mode" {
  description = "Enable privileged mode for the environment"
  type        = bool
  default     = true
}

variable "buildspec_path" {
  description = "Path to the build project buildspec file"
  type        = string
}


variable "deployspec_path" {
  description = "Path to the build project deployspec file"
  type        = string
}

variable "snyk_token" {
  description = "Snyk token"
  type        = string
}
variable "snyk_org_id" {
  description = "Snyk organization ID"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_cluster_arn" {
  description = "EKS cluster name"
  type        = string
}

variable "security_reports_bucket_name" {
  description = "Optional long-lived S3 bucket name for persistent security reports"
  type        = string
  default     = ""
}

variable "security_reports_bucket_arn" {
  description = "Optional ARN for persistent security reports bucket"
  type        = string
  default     = ""
}