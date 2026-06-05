#!/bin/bash
# ================================================================
# fix_cluster.sh
# Minikube --driver=none có quá nhiều dependencies trên Ubuntu 22.04
# Switch sang kind (đơn giản hơn, chỉ cần Docker)
# ================================================================
set -e

APP_NAME="k8s-on-aws"
NODE_PORT="30080"
APP_REPLICAS="2"

echo "=== [1] Remove minikube leftovers ==="
minikube delete 2>/dev/null || true

echo "=== [2] Install kubectl (latest stable) ==="
K8S_VER=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/$K8S_VER/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
kubectl version --client

echo "=== [3] Install kind v0.23.0 ==="
curl -sLo /usr/local/bin/kind \
  "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64"
chmod +x /usr/local/bin/kind
kind version

echo "=== [4] Create kind cluster ==="
mkdir -p /root/.kube

cat > /tmp/kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
EOF

export KUBECONFIG=/root/.kube/config
kind create cluster \
  --name "$APP_NAME" \
  --config /tmp/kind-config.yaml \
  --wait 120s

echo "=== [5] Cluster status ==="
kubectl get nodes

echo "=== [6] Deploy app ==="
# HTML content
mkdir -p /tmp/html
cat > /tmp/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"/>
  <title>K8s on AWS</title>
  <style>
    body { font-family: Arial,sans-serif; background:linear-gradient(135deg,#0f0c29,#302b63,#24243e); min-height:100vh; display:flex; align-items:center; justify-content:center; color:#fff; }
    .card { text-align:center; padding:60px 50px; background:rgba(255,255,255,0.06); border-radius:24px; border:1px solid rgba(255,255,255,0.12); max-width:620px; width:90%; backdrop-filter:blur(12px); box-shadow:0 30px 60px rgba(0,0,0,0.4); }
    h1 { font-size:2.6rem; font-weight:700; color:#ffd200; margin-bottom:14px; }
    .sub { font-size:1.1rem; color:#a8d8ea; line-height:1.7; margin-bottom:28px; }
    .badges { display:flex; flex-wrap:wrap; justify-content:center; gap:8px; }
    .badge { background:rgba(255,210,0,0.12); border:1px solid #ffd200; color:#ffd200; padding:6px 16px; border-radius:20px; font-size:0.82rem; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Xin Chao Ban Be!</h1>
    <p class="sub">App dang chay trong <strong>Kubernetes (kind)</strong><br/>tren EC2 &rarr; expose qua <strong>AWS ALB</strong></p>
    <div class="badges">
      <span class="badge">&#9881; Kubernetes</span>
      <span class="badge">&#9889; kind</span>
      <span class="badge">&#9729; AWS ALB</span>
      <span class="badge">&#128295; Terraform IaC</span>
      <span class="badge">&#128230; nginx</span>
    </div>
  </div>
</body>
</html>
HTMLEOF

kubectl create configmap "${APP_NAME}-html" \
  --from-file=index.html=/tmp/html/index.html \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - << MANIFEST
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: default
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
          requests: {cpu: 50m, memory: 64Mi}
          limits:   {cpu: 200m, memory: 128Mi}
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        readinessProbe:
          httpGet: {path: /, port: 80}
          initialDelaySeconds: 3
          periodSeconds: 5
      volumes:
      - name: html
        configMap:
          name: ${APP_NAME}-html
MANIFEST

kubectl apply -f - << MANIFEST
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-svc
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

echo "=== [7] Wait for rollout ==="
kubectl rollout status deployment/$APP_NAME --timeout=3m

echo "=== DONE ==="
kubectl get pods -o wide
kubectl get svc
sleep 2
curl -s -o /dev/null -w "HTTP_STATUS on :$NODE_PORT = %{http_code}\n" http://localhost:$NODE_PORT/
