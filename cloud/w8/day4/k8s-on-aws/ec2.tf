##############################################################
# ec2.tf — EC2 chạy kind cluster
##############################################################

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

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/output/${var.project_name}-key.pem"
  file_permission = "0600"
}

resource "aws_instance" "k8s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = aws_key_pair.main.key_name

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region   = var.aws_region
    project_name = var.project_name
    app_name     = var.app_name
    node_port    = var.node_port
    app_port     = var.app_port
    app_replicas = var.app_replicas
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-ec2" }
}

# Chờ EC2 chạy xong user_data và push kubeconfig lên SSM
# (Đợi ~2–4 phút, retry đến khi SSM param tồn tại)
resource "time_sleep" "wait_for_user_data" {
  depends_on      = [aws_instance.k8s]
  create_duration = "6m" # Chờ 6 phút: apt + docker + kubectl + kind + awscli

  triggers = {
    instance_id = aws_instance.k8s.id
  }
}

# Đọc kubeconfig từ SSM sau khi EC2 push xong
data "aws_ssm_parameter" "kubeconfig" {
  depends_on = [time_sleep.wait_for_user_data]
  name       = "/${var.project_name}/kubeconfig"
}
