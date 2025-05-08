# AWS Provider configuration
provider "aws" {
  region = us-east-1
}

# Terraform backend and requirements
terraform {
  backend "s3" {
    bucket         = "rigettidemo"  # Replace with your S3 bucket name
    key            = "state-file/eks-terraform.tfstate"
    region         = "us-east-1"              
    dynamodb_table = "terraform-lock-table"   
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
