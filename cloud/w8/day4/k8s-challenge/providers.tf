##############################################################
# providers.tf
#
# Wire 2 provider trong cùng 1 terraform apply:
#
# Provider 1 — AWS
#   Dựng toàn bộ hạ tầng: VPC, EC2, ALB, SG, IAM
#
# Provider 2 — Kubernetes
#   Kết nối vào kind cluster trên EC2.
#   kubeconfig được fetch từ EC2 về file local qua SSH
#   (null_resource.fetch_kubeconfig).
#   kubernetes provider đọc trực tiếp từ file đó.
#
# Thứ tự phụ thuộc:
#   aws_instance
#     → null_resource.wait_for_kind   (SSH poll node Ready)
#       → null_resource.fetch_kubeconfig (SSH copy kubeconfig)
#         → kubernetes provider (config_path)
#           → kubernetes_* resources
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

# kubernetes provider đọc kubeconfig từ file local
# file này được fetch từ EC2 qua SSH (null_resource.fetch_kubeconfig)
# Dùng file() để đọc content sau khi file tồn tại
locals {
  kubeconfig_path = "${path.module}/output/kubeconfig.yaml"
  kubeconfig      = fileexists(local.kubeconfig_path) ? yamldecode(file(local.kubeconfig_path)) : null
}

provider "kubernetes" {
  host = local.kubeconfig != null ? local.kubeconfig["clusters"][0]["cluster"]["server"] : "https://localhost:6443"

  # TLS cert của kind chỉ valid cho internal IPs, skip verify khi dùng public IP
  insecure = true

  client_certificate = local.kubeconfig != null ? base64decode(
    local.kubeconfig["users"][0]["user"]["client-certificate-data"]
  ) : ""

  client_key = local.kubeconfig != null ? base64decode(
    local.kubeconfig["users"][0]["user"]["client-key-data"]
  ) : ""
}
provider "tls" {}
provider "local" {}
provider "null" {}
