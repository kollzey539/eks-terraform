
# Create a new SSH key pair for the bastion host
resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-key-${formatdate("YYYYMMDD", timestamp())}"
  public_key = tls_private_key.bastion_rsa.public_key_openssh
}

# Generate RSA key
resource "tls_private_key" "bastion_rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key to a file (optional)
resource "local_file" "private_key" {
  content  = tls_private_key.bastion_rsa.private_key_pem
  filename = "${aws_key_pair.bastion_key.key_name}.pem"
  file_permission = "0400"
}

# Find an existing public subnet
data "aws_subnet" "public" {
  filter {
    name   = "nat-gateway-subnet"
    values = ["true"]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a"] 
  }
}

# Security group for bastion host (SSH only)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this in production!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Create the bastion host
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

# Get the latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create private ECR repository
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

output "ssh_command" {
  value = "ssh -i ${aws_key_pair.bastion_key.key_name}.pem ec2-user@${aws_instance.bastion.public_ip}"
}
#