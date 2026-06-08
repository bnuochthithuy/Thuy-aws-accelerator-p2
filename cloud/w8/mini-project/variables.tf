##############################################################
# variables.tf
##############################################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix cho tất cả resource"
  type        = string
  default     = "webapp"
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR list cho public subnets (1 subnet / AZ)"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR list cho private subnets (RDS cần >= 2 AZ)"
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type cho web server"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Tên database MySQL"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "MySQL master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "MySQL master password — dùng env var TF_VAR_db_password khi apply"
  type        = string
  sensitive   = true
  default     = "ChangeMe1234!" # đổi khi deploy thật
}

variable "s3_bucket_suffix" {
  description = "Suffix ngẫu nhiên để tạo tên S3 bucket duy nhất"
  type        = string
  default     = "assets"
}
