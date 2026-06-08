##############################################################
# modules/vpc/variables.tf
##############################################################

variable "project_name" {
  description = "Prefix cho tất cả resource trong module"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Danh sách CIDR cho public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Danh sách CIDR cho private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Danh sách AZ để spread subnets"
  type        = list(string)
}
