##############################################################
# versions.tf — Provider requirements
#
# Providers sử dụng:
#   1. hashicorp/aws   — toàn bộ hạ tầng AWS
#   2. hashicorp/tls   — tự gen RSA 4096 SSH key pair cho EC2
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
