terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Credentials come from environment variables:
  #   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
}

# --- S3 bucket: the "data lake" landing zone for file sources ---
resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name
  tags = {
    project    = "snowflake-warehouse"
    managed_by = "terraform"
  }
}

# Keep the bucket private (no public access).
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning (good practice for a data landing zone).
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- Upload the file sources to the bucket ---
resource "aws_s3_object" "web_events" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/web_events.csv"
  source = "${path.module}/../data/sample/web_events.csv"
  etag   = filemd5("${path.module}/../data/sample/web_events.csv")
}

resource "aws_s3_object" "marketing_spend" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/marketing_spend.csv"
  source = "${path.module}/../data/sample/marketing_spend.csv"
  etag   = filemd5("${path.module}/../data/sample/marketing_spend.csv")
}
