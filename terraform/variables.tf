variable "battlefield" {
  description = "Battlefield name aka cluster name"
  type        = string
  default     = "karin"
}

variable "battle" {
  description = "Battle name will be placed as tags"
  type        = string
  default     = "rtfa.life"
}

variable "warrior" {
  description = "Warrior name will be remember in tags"
  type        = string
  default     = "Rodrigo Toledo"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Number of different AZs to use"
  type        = number
  default     = 2
}

variable "aws_vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.13.0.0/16"
}

variable "aws_key_pair_name" {
  description = "AWS Key Pair name to use for EC2 Instances (if already existent)"
  type        = string
  default     = null
}

variable "ssh_private_key_path" {
  description = "SSH private key path"
  type        = string
  default     = "./id_rtfa_life"
}

variable "ssh_public_key_path" {
  description = "SSH public key path (to create a new AWS Key Pair from existing local SSH public RSA key)"
  type        = string
  default     = "./id_rtfa_life.pub"
}

variable "master_instance_type" {
  type        = string
  description = "EC2 instance type for the master node (must have at least 2 CPUs)."
  default     = "t3a.medium"
}

variable "worker_instance_type" {
  type        = string
  description = "EC2 instance type for the worker nodes."
  default     = "t3a.small"
}

variable "hosted_zone" {
  description = "Route53 Hosted Zone for creating records (without . suffix, e.g. `webera.dev`)"
  type        = string
  default     = "rtfa.life"
}