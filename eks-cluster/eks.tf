# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# EKS Cluster
resource "aws_eks_cluster" "primary" {
  name     = "${var.cluster}"
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  }

  version = var.cluster_version
}

# EKS Node Group A in AZ - A
resource "aws_eks_node_group" "node_group_a" {
  cluster_name    = aws_eks_cluster.primary.name
  node_group_name = "node-group-a-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.subnet_a.id]
  instance_types  = ["t3.xlarge"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  ami_type = var.ami_type
  version  = var.cluster_version

  lifecycle {
    create_before_destroy = true
  }
}

# EKS Node Group B in AZ - B
resource "aws_eks_node_group" "node_group_b" {
  cluster_name    = aws_eks_cluster.primary.name
  node_group_name = "node-group-b-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.subnet_b.id]
  instance_types  = ["t3.xlarge"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  ami_type = var.ami_type
  version  = var.cluster_version

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  ]
}



