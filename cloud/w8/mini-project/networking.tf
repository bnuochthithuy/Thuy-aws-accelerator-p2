##############################################################
# networking.tf — Gọi module vpc
#
# Step 1: Create VPC module with public & private subnets
#
# Module vpc tạo:
#   - VPC 10.20.0.0/16
#   - 2 public subnets  (10.20.1.0/24, 10.20.2.0/24)
#   - 2 private subnets (10.20.11.0/24, 10.20.12.0/24)
#   - Internet Gateway + public route table
#   - NAT Gateway + private route table
##############################################################

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # Dùng 2 AZ đầu tiên available trong region
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}
