##############################################################
# ec2.tf — EC2 + SSH Key + user_data + kubeconfig fetch
#
# Approach (không dùng SSM):
#   1. EC2 khởi động, user_data cài Docker + kind + tạo cluster
#   2. null_resource dùng remote-exec SSH vào EC2:
#      - Chờ kind cluster sẵn sàng
#      - Export kubeconfig, patch IP, in ra stdout
#   3. null_resource dùng local-exec chạy trên Windows:
#      - SSH vào EC2, copy kubeconfig về file local
#   4. kubernetes provider đọc kubeconfig từ file local đó
##############################################################

# ── AMI: Ubuntu 22.04 LTS ────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── SSH Key Pair ──────────────────────────────────────────────
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

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

  # Không cần iam_instance_profile nữa (bỏ SSM)
  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    app_name  = var.app_name
    node_port = var.node_port
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-ec2" }
}

# ── Step 1: SSH vào EC2, chờ kind sẵn sàng ───────────────────
resource "null_resource" "wait_for_kind" {
  depends_on = [
    aws_instance.k8s,
    local_sensitive_file.private_key,
  ]

  triggers = {
    instance_id = aws_instance.k8s.id
  }

  connection {
    type        = "ssh"
    host        = aws_instance.k8s.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "12m"
  }

  # Poll đến khi kind cluster có node Ready
  provisioner "remote-exec" {
    inline = [
      "echo '=== Waiting for kind cluster to be Ready ==='",
      "for i in $(seq 1 60); do",
      "  STATUS=$(sudo kubectl --kubeconfig /root/.kube/config get nodes --no-headers 2>/dev/null | awk '{print $2}' | head -1)",
      "  echo \"[$i/60] Node status: $STATUS\"",
      "  if [ \"$STATUS\" = 'Ready' ]; then echo 'Cluster Ready!'; exit 0; fi",
      "  sleep 15",
      "done",
      "echo 'TIMEOUT waiting for cluster'; exit 1"
    ]
  }
}

# ── Step 2: Copy kubeconfig từ EC2 về máy local ──────────────
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [null_resource.wait_for_kind]

  triggers = {
    instance_id = aws_instance.k8s.id
  }

  # Chạy trên máy local (Windows): SSH copy kubeconfig về
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-PS
      $keyPath = "${replace(local_sensitive_file.private_key.filename, "\\", "/")}"
      $host_ip = "${aws_instance.k8s.public_ip}"
      $outFile = "${replace(path.module, "\\", "/")}/output/kubeconfig.yaml"

      # Fix key permissions on Windows
      icacls $keyPath /inheritance:r | Out-Null
      icacls $keyPath /grant:r "$env:USERNAME`:R" | Out-Null

      # SSH vào EC2, export kubeconfig đã patch IP, lưu về local với UTF8 encoding
      $content = ssh -i $keyPath `
        -o StrictHostKeyChecking=no `
        -o UserKnownHostsFile=/dev/null `
        ubuntu@$host_ip `
        "sudo sed -e 's|https://127.0.0.1|https://${aws_instance.k8s.public_ip}|g' -e 's|https://0.0.0.0|https://${aws_instance.k8s.public_ip}|g' /root/.kube/config"
      [System.IO.File]::WriteAllText($outFile, ($content -join "`n"), [System.Text.Encoding]::UTF8)

      Write-Host "Kubeconfig saved to $outFile"
      Get-Content $outFile | Select-String "server:"
    PS
  }
}
