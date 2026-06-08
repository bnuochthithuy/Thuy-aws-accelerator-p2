##############################################################
# security_groups.tf — Security Groups cho EC2 và RDS
#
# Step 5: Configure security groups to allow only required traffic
#
# Traffic rules:
#   sg_web  — EC2 web server
#     ingress :80   from 0.0.0.0/0       (HTTP public)
#     ingress :443  from 0.0.0.0/0       (HTTPS public)
#     ingress :22   from operator IP /32  (SSH restricted)
#     egress  all   to 0.0.0.0/0
#
#   sg_rds  — RDS MySQL (private subnet)
#     ingress :3306 from sg_web ONLY      (web server → DB)
#     egress  all   to 0.0.0.0/0
#
# Dùng http provider để lấy public IP của máy chạy Terraform
# → SSH ingress chỉ cho phép IP đó, không mở 0.0.0.0/0
##############################################################

# ── http provider: lấy public IP hiện tại ────────────────────
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_cidr = "${trimspace(data.http.my_ip.response_body)}/32"
}

# ── Security Group: EC2 Web Server ───────────────────────────
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Web server: HTTP/HTTPS from Internet, SSH from operator only"
  vpc_id      = module.vpc.vpc_id

  # HTTP từ Internet
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS từ Internet
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH chỉ từ IP của operator (http provider)
  ingress {
    description = "SSH from operator IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-web-sg" }
}

# ── Security Group: RDS MySQL ─────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS MySQL: port 3306 from web SG only"
  vpc_id      = module.vpc.vpc_id

  # MySQL 3306 — chỉ từ web server SG
  ingress {
    description     = "MySQL from web server only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}
