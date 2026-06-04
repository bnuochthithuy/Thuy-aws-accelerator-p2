terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Provider 1: AWS — hạ tầng (VPC, EC2, ALB, IAM, SSM)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Provider 2: Kubernetes — deploy app vào kind cluster
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    # Provider phụ trợ
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
