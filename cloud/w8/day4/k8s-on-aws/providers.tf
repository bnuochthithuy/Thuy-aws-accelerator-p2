##############################################################
# providers.tf — Wire 4 provider trong 1 terraform apply
#
# Luồng wire:
#
#   http provider
#     → data.http.my_ip  (GET https://checkip.amazonaws.com)
#     → local.my_cidr    ("1.2.3.4/32")
#     → aws_security_group.ec2 ingress SSH rule
#       (chỉ cho phép IP của máy đang chạy Terraform SSH vào EC2)
#
#   tls provider
#     → tls_private_key.ssh   (RSA 4096)
#     → aws_key_pair.main     (public key lên AWS)
#     → local_sensitive_file  (private key ra output/*.pem)
#
#   local provider
#     → local_sensitive_file.private_key
#       (ghi .pem với permission 0600 — dùng để SSH debug)
#
#   aws provider
#     → VPC, Subnet, IGW, Route Table
#     → Security Groups (ALB + EC2)
#     → EC2 instance (chạy minikube + deploy app qua user_data)
#     → ALB → Target Group → Listener
##############################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Env       = "lab"
    }
  }
}

# http provider: lấy public IP của máy đang chạy Terraform
# Dùng để tạo SSH ingress rule chỉ cho phép IP này
provider "http" {}

provider "tls" {}

provider "local" {}
