##############################################################
# providers.tf
# Wire 2 provider trong cùng 1 cấu hình Terraform:
#   1. AWS provider  — dựng hạ tầng (VPC, EC2, ALB)
#   2. Kubernetes provider — deploy app vào kind cluster trên EC2
#
# Cách wire: kubernetes provider lấy kubeconfig từ file
# được EC2 user_data tạo ra và copy ra ngoài qua SSM Parameter.
# Terraform dùng `depends_on` + `data.aws_ssm_parameter` để
# chờ EC2 hoàn tất setup trước khi gọi kubernetes provider.
##############################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "lab"
    }
  }
}

# Kubernetes provider được wire vào kind cluster chạy trên EC2.
# kubeconfig được EC2 push lên SSM Parameter Store sau khi kind sẵn sàng.
# Terraform đọc SSM → decode → truyền vào kubernetes provider.
provider "kubernetes" {
  host                   = yamldecode(data.aws_ssm_parameter.kubeconfig.value)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(data.aws_ssm_parameter.kubeconfig.value)["clusters"][0]["cluster"]["certificate-authority-data"])
  token                  = yamldecode(data.aws_ssm_parameter.kubeconfig.value)["users"][0]["user"]["token"]
}

provider "tls" {}
provider "local" {}
provider "time" {}
