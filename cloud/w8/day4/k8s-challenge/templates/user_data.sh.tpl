#!/bin/bash
# =============================================================
# user_data.sh — Cài Docker + kind cluster trên EC2
# Không cần SSM. Terraform fetch kubeconfig qua SSH sau.
# kind API server dùng port 6443 cố định.
# =============================================================

LOG=/var/log/user_data.log
exec > >(tee -a $LOG) 2>&1

APP_NAME="${app_name}"
NODE_PORT="${node_port}"

echo "[$(date)] === START user_data ==="

# ─── 1. System update ────────────────────────────────────────
echo "[$(date)] [1/4] System update"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q
apt-get install -y -q curl wget unzip

# ─── 2. Docker ───────────────────────────────────────────────
echo "[$(date)] [2/4] Install Docker"
curl -fsSL https://get.docker.com | bash
systemctl enable docker
systemctl start docker
for i in $(seq 1 12); do
  docker info > /dev/null 2>&1 && echo "Docker ready" && break
  echo "Waiting for Docker ($i/12)..."
  sleep 5
done

# ─── 3. kubectl ──────────────────────────────────────────────
echo "[$(date)] [3/4] Install kubectl"
K8S_VER=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/$K8S_VER/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# ─── 4. kind + cluster ───────────────────────────────────────
echo "[$(date)] [4/4] Install kind + create cluster"
curl -sLo /usr/local/bin/kind \
  "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64"
chmod +x /usr/local/bin/kind

# kind config:
#   apiServerAddress: 0.0.0.0 → bind tất cả interface
#   apiServerPort: 6443       → port cố định (không random)
#   extraPortMappings         → NodePort → host port
printf '%s\n' \
  'kind: Cluster' \
  'apiVersion: kind.x-k8s.io/v1alpha4' \
  'networking:' \
  '  apiServerAddress: "0.0.0.0"' \
  '  apiServerPort: 6443' \
  'nodes:' \
  '  - role: control-plane' \
  '    extraPortMappings:' \
  "      - containerPort: $NODE_PORT" \
  "        hostPort: $NODE_PORT" \
  '        protocol: TCP' \
  > /tmp/kind-config.yaml

cat /tmp/kind-config.yaml

export KUBECONFIG=/root/.kube/config
mkdir -p /root/.kube

kind create cluster \
  --name "$APP_NAME" \
  --config /tmp/kind-config.yaml \
  --wait 120s

echo "[$(date)] === Cluster ready ==="
kubectl get nodes
kubectl cluster-info
