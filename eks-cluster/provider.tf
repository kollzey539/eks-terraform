# AWS Provider configuration
provider "aws" {
  region = var.region
}

# Terraform backend and requirements
terraform {
  backend "s3" {
    bucket         = "rigettidemo"  # Replace with your S3 bucket name
    key            = "state-file/eks-terraform.tfstate"
    region         = "us-east-1"              # Replace with your preferred region
    dynamodb_table = "terraform-lock-table"   # Name of your DynamoDB table for locks
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


#
