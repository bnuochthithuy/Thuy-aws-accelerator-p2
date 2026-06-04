##############################################################
# security_groups.tf — SG cho ALB và EC2
#
# Luồng traffic:
#   Internet :80 → ALB SG → ALB
#   ALB → EC2 SG :30080 (NodePort) → EC2 → kind → Pod
#
# EC2 SG còn mở:
#   :22  — SSH (Terraform remote-exec dùng để poll SSM)
#   :6443 — Kubernetes API (kubernetes provider kết nối)
##############################################################

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
    description = "All outbound"
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
  description = "EC2: NodePort from ALB, SSH and K8s API"
  vpc_id      = aws_vpc.main.id

  # NodePort — ALB health check + forward traffic
  ingress {
    description     = "NodePort from ALB"
    from_port       = var.node_port
    to_port         = var.node_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH — Terraform remote-exec dùng để poll SSM readiness
  ingress {
    description = "SSH for Terraform remote-exec"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API — port 6443 cố định (apiServerPort trong kind config)
  ingress {
    description = "K8s API server port 6443"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ec2-sg" }
}
