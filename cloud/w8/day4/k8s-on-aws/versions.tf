##############################################################
# versions.tf — Provider requirements
#
# 4 provider được wire trong cùng 1 terraform apply:
#   1. hashicorp/aws   — hạ tầng AWS (VPC, EC2, ALB, SG)
#   2. hashicorp/tls   — tự gen RSA 4096 SSH key pair
#   3. hashicorp/local — ghi private key ra file .pem local
#   4. hashicorp/http  — lấy public IP hiện tại để giới hạn SSH ingress
##############################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}
