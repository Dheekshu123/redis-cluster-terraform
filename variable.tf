variable "aws_region" {
  description = "The AWS region to create resources in"
  default     = "us-east-1"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  default     = 4
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  default     = "ami-07a6f770277670015" # Replace with your desired Amazon Linux 2 AMI ID
}

variable "key_name" {
  description = "Key pair name to access EC2 instances"
  default     = "demo-key" # Replace with your key pair name
}

variable "security_group_name" {
  description = "Name of the security group"
  default     = "redis-security-group"
}

variable "iam_role_name" {
  description = "Name of the IAM role for EC2 instances"
  default     = "redis-ec2-role"
}

variable "docker_image" {
  description = "Docker image for Redis"
  default     = "zero2pro1/redis:7.2"
}

variable "redis_password" {
  description = "Password for Redis instances"
  default     = "redis123"
}
