##############################################################
# ec2.tf — SSH Key (tls + local provider) + EC2 instance
#
# Wire point 2 — tls provider:
#   tls_private_key.ssh → public key → aws_key_pair (lên AWS)
#                       → private key → local_sensitive_file (ra .pem)
#
# Wire point 3 — local provider:
#   local_sensitive_file → ghi file output/*.pem permission 0600
#
# EC2 user_data:
#   Cài Docker, kubectl, minikube (--driver=none / bare-metal)
#   Deploy app nginx + service NodePort hoàn toàn trong user_data
#   Không cần SSM, không cần remote-exec
##############################################################

# ── AMI: Ubuntu 22.04 LTS ────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── tls provider: tự gen RSA 4096 SSH key pair ───────────────
# Wire point 2: tls_private_key → aws_key_pair + local_sensitive_file
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Public key lên AWS
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# ── local provider: ghi private key ra file .pem ─────────────
# Wire point 3: local_sensitive_file ← tls_private_key.private_key_pem
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/output/${var.project_name}-key.pem"
  file_permission = "0600"
}

# ── EC2 Instance ──────────────────────────────────────────────
resource "aws_instance" "k8s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.main.key_name

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    app_name     = var.app_name
    app_replicas = var.app_replicas
    node_port    = var.node_port
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-ec2" }
}
