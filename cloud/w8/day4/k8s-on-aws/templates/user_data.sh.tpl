#!/bin/bash
# =============================================================
# user_data.sh — Cai minikube (--driver=none) tren EC2
#                Deploy app nginx vao K8s qua kubectl
#
# --driver=none (bare-metal mode):
#   minikube chay truc tiep tren host, khong can VM driver
#   Kubernetes components (apiserver, etcd...) chay nhu process
#   tren EC2 thay vi ben trong VM/container
#   → Phu hop cho EC2 Linux, khong can nested virtualization
#
# Flow:
#   [1] Cai conntrack, socat (dependency cua kubeadm)
#   [2] Cai Docker (container runtime cho Pod)
#   [3] Cai kubectl
#   [4] Cai minikube binary
#   [5] minikube start --driver=none
#   [6] kubectl apply: Deployment + Service (NodePort)
#   [7] Confirm pod Running
# =============================================================

LOG=/var/log/user_data.log
exec > >(tee -a "$LOG") 2>&1

APP_NAME="${app_name}"
APP_REPLICAS="${app_replicas}"
NODE_PORT="${node_port}"

echo "[$(date)] === START user_data ==="

# ── [1] System deps ──────────────────────────────────────────
echo "[$(date)] [1/6] System update + deps"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q
apt-get install -y -q \
  curl wget unzip \
  conntrack socat \
  apt-transport-https ca-certificates gnupg

# crictl — bắt buộc cho minikube --driver=none với K8s >= 1.24
CRICTL_VER="v1.30.1"
curl -sL "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VER}/crictl-${CRICTL_VER}-linux-amd64.tar.gz" \
  | tar -xz -C /usr/local/bin
echo "crictl installed: $(crictl --version)"

# ── [2] Docker ───────────────────────────────────────────────
echo "[$(date)] [2/6] Install Docker"
curl -fsSL https://get.docker.com | bash
systemctl enable docker
systemctl start docker

# Doi Docker daemon san sang
for i in $(seq 1 15); do
  docker info > /dev/null 2>&1 && echo "Docker ready after $i tries" && break
  sleep 5
done

# ── [3] kubectl ──────────────────────────────────────────────
echo "[$(date)] [3/6] Install kubectl"
K8S_VER=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/$K8S_VER/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
kubectl version --client

# ── [4] minikube ─────────────────────────────────────────────
echo "[$(date)] [4/6] Install minikube"
curl -sLo /usr/local/bin/minikube \
  "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
chmod +x /usr/local/bin/minikube
minikube version

# ── [5] minikube start --driver=none ─────────────────────────
# --driver=none: chay K8s components truc tiep tren host (khong VM)
# --kubernetes-version: pin phien ban tranh breaking changes
# Phai chay bang root hoac user co quyen Docker
echo "[$(date)] [5/6] Start minikube (driver=none)"
minikube start \
  --driver=none \
  --kubernetes-version=v1.30.0 \
  --extra-config=apiserver.bind-address=0.0.0.0 \
  --wait=all

echo "--- minikube status ---"
minikube status
kubectl get nodes
kubectl cluster-info

# Copy kubeconfig ve /home/ubuntu de SSH debug de dang
mkdir -p /home/ubuntu/.kube
cp /root/.kube/config /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# ── [6] Deploy app vao K8s ───────────────────────────────────
echo "[$(date)] [6/6] Deploy app to Kubernetes"

# Tao HTML content cho nginx
mkdir -p /tmp/html
cat > /tmp/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>K8s on AWS</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Segoe UI', Arial, sans-serif;
      background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #fff;
    }
    .card {
      text-align: center;
      padding: 60px 50px;
      background: rgba(255,255,255,0.06);
      border-radius: 24px;
      border: 1px solid rgba(255,255,255,0.12);
      max-width: 620px;
      width: 90%;
      backdrop-filter: blur(12px);
      box-shadow: 0 30px 60px rgba(0,0,0,0.4);
    }
    .icon { font-size: 72px; margin-bottom: 20px; }
    h1 { font-size: 2.6rem; font-weight: 700; color: #ffd200; margin-bottom: 14px; }
    .sub { font-size: 1.1rem; color: #a8d8ea; line-height: 1.7; margin-bottom: 10px; }
    .note { font-size: 0.9rem; color: #aaa; margin-bottom: 28px; }
    .badges { display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; }
    .badge {
      background: rgba(255,210,0,0.12);
      border: 1px solid #ffd200;
      color: #ffd200;
      padding: 6px 16px;
      border-radius: 20px;
      font-size: 0.82rem;
    }
    .divider { border: none; border-top: 1px solid rgba(255,255,255,0.1); margin: 28px 0; }
    .stack { font-size: 0.8rem; color: #777; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">&#x2638;&#xFE0F;</div>
    <h1>Xin Chao Ban Be!</h1>
    <p class="sub">
      App dang chay trong <strong>Kubernetes (minikube)</strong><br/>
      tren EC2 &#x2192; expose qua <strong>AWS ALB</strong>
    </p>
    <p class="note">Tu dong hoa 100% bang Terraform &#x1F680; Khong lam tay.</p>
    <div class="badges">
      <span class="badge">&#x2638; Kubernetes</span>
      <span class="badge">&#x1F6F3; minikube</span>
      <span class="badge">&#x2601; AWS ALB</span>
      <span class="badge">&#x1F527; Terraform IaC</span>
      <span class="badge">&#x1F4E6; nginx</span>
    </div>
    <hr class="divider"/>
    <p class="stack">EC2 t3.medium &#x2022; Ubuntu 22.04 &#x2022; minikube latest &#x2022; K8s stable</p>
  </div>
</body>
</html>
HTMLEOF

# Tao ConfigMap tu file HTML
kubectl create configmap "$APP_NAME-html" \
  --from-file=index.html=/tmp/html/index.html \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply Deployment
kubectl apply -f - << MANIFEST
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: default
  labels:
    app: $APP_NAME
    managed-by: terraform-user-data
spec:
  replicas: $APP_REPLICAS
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: $APP_NAME
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 5
      volumes:
      - name: html
        configMap:
          name: $APP_NAME-html
MANIFEST

# Apply Service NodePort
kubectl apply -f - << MANIFEST
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME-svc
  namespace: default
spec:
  type: NodePort
  selector:
    app: $APP_NAME
  ports:
  - port: 80
    targetPort: 80
    nodePort: $NODE_PORT
MANIFEST

# Doi pod Running
echo "[$(date)] Waiting for pods to be Running..."
kubectl rollout status deployment/"$APP_NAME" --timeout=3m

echo "--- Final cluster state ---"
kubectl get nodes
kubectl get pods -o wide
kubectl get svc

echo "[$(date)] === DONE: minikube + app deployed on NodePort $NODE_PORT ==="
