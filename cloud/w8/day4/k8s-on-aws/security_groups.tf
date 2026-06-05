##############################################################
# security_groups.tf — SG cho ALB và EC2
#
# Wire http provider ở đây:
#   data.http.my_ip → lấy public IP của máy chạy Terraform
#   → SSH ingress chỉ cho phép IP đó thay vì 0.0.0.0/0
#
# Traffic flow:
#   Internet :80 → ALB SG → ALB
#   ALB → EC2 SG :30080 (NodePort) → minikube → Pod
#   <my_ip>/32 → EC2 SG :22 → SSH (debug)
##############################################################

# ── http provider: lấy public IP hiện tại ────────────────────
# Wire point 1: http provider → security group ingress rule
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  # Trim whitespace/newline từ response, append /32
  my_cidr = "${trimspace(data.http.my_ip.response_body)}/32"
}

# ── ALB Security Group ────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB: allow HTTP from Internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# ── EC2 Security Group ────────────────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2: NodePort from ALB, SSH from operator IP only"
  vpc_id      = aws_vpc.main.id

  # NodePort — ALB forward traffic vào đây
  ingress {
    description     = "NodePort from ALB"
    from_port       = var.node_port
    to_port         = var.node_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH — chỉ cho phép IP của máy đang chạy Terraform (từ http provider)
  # Wire point 1: data.http.my_ip → local.my_cidr → ingress rule
  # Lưu ý: nếu IP thay đổi sau khi apply, chạy `terraform apply` lại
  #         để cập nhật rule, hoặc thêm tay bằng AWS CLI
  ingress {
    description = "SSH from operator IP only (via http provider)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr, "0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ec2-sg" }
}
