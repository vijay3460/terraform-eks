# AWS Config

variable "aws_access_key" {
  default = "key"
}

variable "aws_secret_key" {
  default = "key"
}

variable "aws_region" {
  default = "ap-south-1"
}

variable "cidr_vpc" {
  description = "CIDR block for the VPC"
  default = "10.20.0.0/16"
}
variable "public-subnet-1a" {
  description = "CIDR block for the public subnet 1a"
  default = "10.20.1.0/24"
}
variable "public-subnet-1b" {
  description = "CIDR block for the public subnet 1b"
  default = "10.20.2.0/24"
}

variable "private-subnet-1a" {
  description = "CIDR block for the private subnet 1a"
  default = "10.20.3.0/24"
}

variable "private-subnet-1b" {
  description = "CIDR block for the priavate subnet 1b"
  default = "10.20.4.0/24"
}



variable "az-1a" {
  description = "availability zone to create subnet"
  default = "ap-south-1a"
}

variable "az-1b" {
  description = "availability zone to create subnet"
  default = "ap-south-1b"
}

variable "environment_tag" {
  description = "Environment tag"
  default = "Production"
}

variable "key" {
  description = "key value"
  default = "anand"
}

variable "instance_type" {
  description = "small instace"
  default = "t2.small"
}

variable "ami" {
  description = "ecs ami"
  default = "ami-0bb00e728f56a421b"
}

variable "cluster-name" {
  default = "terraform-eks-demo"
}

variable "eks-ami" {
  description = "eks ami"
  default = "ami-096122757b4163b0e"
}
