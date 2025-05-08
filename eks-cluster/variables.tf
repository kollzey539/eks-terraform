
variable "cluster_version" {
  description = "The desired version prefix for the GKE cluster."
  type        = string
  default     = "1.30"
}

variable "cluster" {
  description = "The name of the GKE cluster."
  type        = string
}

variable "ami_type" {
  description = "The AMI Version of the node"
  type        = string
  default     = "AL2_x86_64"  # Amazon Linux 2 (x86)
}



variable "region" {
  description = "The GCP region where the GKE cluster and node pools will be deployed."
  type        = string
  default     = "us-east-1"
}

