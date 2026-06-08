##############################################################
# providers.tf
#
# Provider wire:
#   http  → data.http.my_ip → SSH ingress chỉ từ IP của operator
#   tls   → RSA 4096 key pair → aws_key_pair + local .pem
#   local → ghi private key ra output/*.pem (0600)
#   aws   → VPC, Subnets, EC2, RDS, S3, Security Groups
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

provider "http" {}
provider "tls" {}
provider "local" {}
