# Configure Kubernetes provider for EKS
provider "kubernetes" {
  host                   = data.aws_eks_cluster.primary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.primary.token
}

# Configure Helm provider for EKS
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.primary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.primary.token
  }
}

# AWS S3 backend for Terraform state
terraform {
  backend "s3" {
    bucket = "rigettidemo"
    key    = "state-file/helm-updates.tfstate"
    region = "us-east-1"  
    
    # Optional: Enable state locking with DynamoDB
    # dynamodb_table = "terraform-lock-table"
    # encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}