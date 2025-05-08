# Use existing CI/CD system's SSH key
resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-key-${formatdate("YYYYMMDD", timestamp())}"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..." # Your CI/CD system's public key
}

# Reference existing VPC
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["main-vpc"]
  }
}

# Reference existing public subnet
data "aws_subnet" "public" {
  filter {
    name   = "tag:Name"
    values = ["nat-gateway-subnet"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

# Security group with open inbound SSH (default egress)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Allow SSH from anywhere"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to all (adjust for production)
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Bastion host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.bastion_key.key_name

  tags = {
    Name = "bastion-host"
  }
}

# Latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ECR repository
resource "aws_ecr_repository" "rigetti_demo" {
  name                 = "rigettidemo"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.rigetti_demo.repository_url
}