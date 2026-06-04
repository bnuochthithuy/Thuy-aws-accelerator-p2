#!/bin/bash
# =============================================================
# EC2 User Data — cài kind cluster + push kubeconfig lên SSM
# App được Terraform deploy qua kubernetes provider (k8s_app.tf)
# =============================================================

REGION="${aws_region}"
PROJECT="${project_name}"
APP_NAME="${app_name}"
NODE_PORT="${node_port}"
SSM_PARAM="/$PROJECT/kubeconfig"

LOG=/var/log/user_data.log
exec > >(tee -a $LOG) 2>&1

set -uxo pipefail   # -e bị bỏ để lỗi không crash toàn script

echo "=== [1/5] Cập nhật hệ thống ==="
apt-get update -y
apt-get install -y curl wget unzip

echo "=== [2/5] Cài Docker ==="
curl -fsSL https://get.docker.com | bash
systemctl enable docker
systemctl start docker
# Đợi Docker thực sự sẵn sàng
sleep 5
docker info

echo "=== [3/5] Cài kubectl ==="
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "=== [4/5] Cài kind + tạo cluster ==="
curl -Lo /usr/local/bin/kind \
  "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64"
chmod +x /usr/local/bin/kind

# Kind config với extraPortMappings
# Dùng printf thay heredoc để tránh conflict với Terraform templatefile
printf 'kind: Cluster\napiVersion: kind.x-k8s.io/v1alpha4\nnodes:\n  - role: control-plane\n    extraPortMappings:\n      - containerPort: ${node_port}\n        hostPort: ${node_port}\n        protocol: TCP\n' \
  > /tmp/kind-config.yaml

echo "--- kind config ---"
cat /tmp/kind-config.yaml

export KUBECONFIG=/root/.kube/config
mkdir -p /root/.kube

kind create cluster \
  --name "$APP_NAME" \
  --config /tmp/kind-config.yaml \
  --wait 120s

echo "--- Cluster info ---"
kubectl cluster-info
kubectl get nodes

# Xác nhận file kubeconfig tồn tại
ls -la /root/.kube/
echo "kubeconfig content (first 5 lines):"
head -5 /root/.kube/config

echo "=== [5/5] Push kubeconfig lên SSM ==="

# Cài awscli v2
curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install --update
rm -rf /tmp/awscliv2.zip /tmp/aws

# Lấy private IP
EC2_PRIVATE_IP=$(curl -sf http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Private IP: $EC2_PRIVATE_IP"

# Patch kubeconfig: đổi 127.0.0.1 → private IP
KUBECONFIG_PATCHED=$(sed \
  -e "s|https://127.0.0.1|https://$EC2_PRIVATE_IP|g" \
  -e "s|https://localhost|https://$EC2_PRIVATE_IP|g" \
  /root/.kube/config)

echo "--- Patched server line ---"
echo "$KUBECONFIG_PATCHED" | grep "server:"

/usr/local/bin/aws ssm put-parameter \
  --region "$REGION" \
  --name "$SSM_PARAM" \
  --value "$KUBECONFIG_PATCHED" \
  --type "SecureString" \
  --overwrite

echo "=== DONE: kubeconfig pushed to SSM $SSM_PARAM ==="
