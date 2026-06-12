variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally-unique S3 bucket name (set in terraform.tfvars)."
  type        = string
}
