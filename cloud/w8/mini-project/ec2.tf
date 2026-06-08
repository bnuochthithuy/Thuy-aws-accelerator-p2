##############################################################
# ec2.tf — SSH Key + EC2 Web Server
#
# Step 2: Deploy EC2 instance in public subnet (web server)
#
# Wire:
#   tls_private_key → aws_key_pair (lên AWS)
#                   → local_sensitive_file (ra output/*.pem)
#
# EC2 nằm trong public subnet, chạy nginx qua user_data
# Security group chỉ mở :80, :443, và SSH từ operator IP
##############################################################

# ── AMI: Ubuntu 22.04 LTS (Canonical) ────────────────────────
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

# ── tls provider: gen RSA 4096 SSH key pair ───────────────────
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# ── local provider: ghi private key ra .pem ──────────────────
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/output/${var.project_name}-key.pem"
  file_permission = "0600"
}

# ── EC2 Instance: Web Server (public subnet) ─────────────────
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    project_name = var.project_name
    db_host      = aws_db_instance.mysql.address
    db_name      = var.db_name
    s3_bucket    = aws_s3_bucket.assets.bucket
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  # Đảm bảo RDS và S3 tồn tại trước khi render user_data
  depends_on = [aws_db_instance.mysql, aws_s3_bucket.assets]

  tags = { Name = "${var.project_name}-web-ec2" }
}
