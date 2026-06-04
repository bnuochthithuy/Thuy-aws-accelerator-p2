# K8s on AWS — Terraform 1-Click

> Dựng EC2 + kind cluster + deploy app + expose qua ALB  
> Toàn bộ tự động hóa bằng **1 lệnh `terraform apply`**

---

## Sơ Đồ Kiến Trúc

```
                        ┌─────────────────────────────────────────┐
Internet                │           AWS (ap-southeast-1)          │
   │                    │                                         │
   │ HTTP :80           │  ┌──────────────────────────────────┐   │
   ▼                    │  │         VPC 10.10.0.0/16         │   │
┌──────────┐            │  │                                  │   │
│ Browser  │──────────► │  │  ┌──────────┐   ┌───────────┐   │   │
└──────────┘            │  │  │  Subnet  │   │  Subnet   │   │   │
                        │  │  │  AZ-1a   │   │  AZ-1b    │   │   │
                        │  │  └────┬─────┘   └─────┬─────┘   │   │
                        │  │       │               │          │   │
                        │  │  ┌────▼───────────────▼──────┐   │   │
                        │  │  │      AWS ALB (HTTP :80)   │   │   │
                        │  │  └────────────┬──────────────┘   │   │
                        │  │               │ :30080 NodePort   │   │
                        │  │  ┌────────────▼──────────────┐   │   │
                        │  │  │   EC2 t3.medium            │   │   │
                        │  │  │   Ubuntu 22.04             │   │   │
                        │  │  │                            │   │   │
                        │  │  │  ┌──────────────────────┐  │   │   │
                        │  │  │  │   kind cluster        │  │   │   │
                        │  │  │  │   API: port 6443      │  │   │   │
                        │  │  │  │                       │  │   │   │
                        │  │  │  │  K8s Service          │  │   │   │
                        │  │  │  │  NodePort :30080      │  │   │   │
                        │  │  │  │       │               │  │   │   │
                        │  │  │  │  ┌────┴────┐          │  │   │   │
                        │  │  │  │  │  Pod 1  │          │  │   │   │
                        │  │  │  │  │  nginx  │          │  │   │   │
                        │  │  │  │  └─────────┘          │  │   │   │
                        │  │  │  │  ┌─────────┐          │  │   │   │
                        │  │  │  │  │  Pod 2  │          │  │   │   │
                        │  │  │  │  │  nginx  │          │  │   │   │
                        │  │  │  │  └─────────┘          │  │   │   │
                        │  │  │  └──────────────────────┘  │   │   │
                        │  │  └───────────────────────────┘   │   │
                        │  └──────────────────────────────────┘   │
                        └─────────────────────────────────────────┘

Provider 1: hashicorp/aws        → VPC, EC2, ALB, Security Groups
Provider 2: hashicorp/kubernetes → ConfigMap, Deployment, Service
```

---

## Cách Wire Provider

### Vấn đề

Terraform cần kết nối vào K8s cluster trên EC2 **trong cùng 1 apply**, nhưng EC2 chưa tồn tại lúc bắt đầu. Đây là bài toán chicken-and-egg: `kubernetes` provider cần địa chỉ cluster, cluster chỉ có sau khi EC2 boot xong.

### Giải pháp: Bridge qua file kubeconfig

```
terraform apply
│
├─ [Provider 1: AWS]
│   aws_instance.k8s
│   └── user_data: cài Docker + kind → cluster sẵn sàng
│         ↓
│   null_resource.wait_for_kind
│   └── remote-exec: SSH vào EC2, poll "kubectl get nodes" cho đến Ready
│         ↓
│   null_resource.fetch_kubeconfig
│   └── local-exec: SSH copy /root/.kube/config → output/kubeconfig.yaml
│         (patch 0.0.0.0 → EC2 public IP)
│
└─ [Provider 2: Kubernetes]
    đọc output/kubeconfig.yaml
    └── kubernetes_config_map  (HTML content)
        kubernetes_deployment  (2 nginx pods)
        kubernetes_service     (NodePort :30080)
```

### Code wire trong `providers.tf`

```hcl
locals {
  kubeconfig_path = "${path.module}/output/kubeconfig.yaml"
  kubeconfig = fileexists(local.kubeconfig_path)
              ? yamldecode(file(local.kubeconfig_path))
              : null
}

provider "kubernetes" {
  # host lấy từ kubeconfig đã fetch về — EC2 public IP:6443
  host     = local.kubeconfig["clusters"][0]["cluster"]["server"]
  insecure = true  # kind cert chỉ valid cho internal IP, không cho public IP

  client_certificate = base64decode(
    local.kubeconfig["users"][0]["user"]["client-certificate-data"]
  )
  client_key = base64decode(
    local.kubeconfig["users"][0]["user"]["client-key-data"]
  )
}
```

**Tại sao `insecure = true`?**  
kind tự ký TLS cert chỉ ghi SAN cho internal IPs (`172.18.0.2`, `0.0.0.0`). Khi connect từ ngoài qua public IP, cert không match → skip TLS verify.

**Tại sao dùng file thay vì SSM / environment variable?**  
`provider` config được evaluate lúc `plan`, trước khi bất kỳ resource nào chạy. File là cách duy nhất để truyền dữ liệu từ apply trước sang provider config mà không cần thêm infra phụ.

---

## Yêu Cầu

- Terraform >= 1.5.0
- AWS CLI đã configure (`aws configure`)
- SSH client (có sẵn trên Windows 10+)
- Quyền IAM: EC2, VPC, ALB, SG

---

## Lệnh Chạy

### Deploy (1-click)

```bash
cd cloud/w8/day4/k8s-challenge

# Bước 1: Init providers
terraform init

# Bước 2: Deploy toàn bộ hạ tầng + K8s app
terraform apply
# gõ "yes" khi được hỏi
```

Quá trình:
```
0–1 phút   → Tạo VPC, SG, ALB, EC2
1–3 phút   → EC2 boot, cài Docker + kind (user_data chạy ngầm)
3–5 phút   → Terraform SSH poll node Ready, fetch kubeconfig
5–6 phút   → Deploy K8s ConfigMap, Deployment, Service
```

Kết quả sau khi xong:
```
alb_url = "http://<alb-dns>.ap-southeast-1.elb.amazonaws.com"
```

**Chờ thêm 1–2 phút** để ALB health check xanh, sau đó mở URL trên browser.

### Kiểm Tra

```bash
# Xem tất cả outputs
terraform output

# SSH vào EC2 debug
ssh -i output/k8s-challenge-key.pem ubuntu@<EC2_IP>

# Trên EC2: kiểm tra K8s
sudo kubectl --kubeconfig /root/.kube/config get pods
sudo kubectl --kubeconfig /root/.kube/config get svc
```

### Destroy (dọn sạch)

```bash
terraform destroy
# gõ "yes" khi được hỏi
```

---

## Cấu Trúc File

```
k8s-challenge/
├── versions.tf          — khai báo providers (aws, kubernetes, tls, local, null)
├── providers.tf         — wire AWS + Kubernetes provider
├── variables.tf         — các biến (region, instance_type, node_port...)
├── networking.tf        — VPC, 2 public subnets, IGW, route table
├── security_groups.tf   — SG cho ALB (:80) và EC2 (:22, :6443, :30080)
├── ec2.tf               — EC2, SSH key, wait_for_kind, fetch_kubeconfig
├── alb.tf               — ALB, Target Group, Listener
├── k8s_app.tf           — ConfigMap, Deployment, Service
├── outputs.tf           — alb_url, ssh_command, k8s_info
├── templates/
│   └── user_data.sh.tpl — script EC2 boot: cài Docker + kind
└── output/              — SSH key + kubeconfig (tự sinh, không commit)
```

---

## Giải Thích Thiết Kế

| Quyết định | Lý do |
|---|---|
| Dùng **kind** thay minikube | Nhẹ hơn, chạy trong Docker, không cần VM driver, startup ~90s |
| **NodePort** thay Ingress | Đơn giản nhất để wire ALB với 1 EC2, không cần cài ingress-nginx |
| **SSH fetch kubeconfig** thay SSM | Không cần IAM role, không giới hạn 4096 ký tự, không tốn phí SSM Advanced |
| **`insecure = true`** trong K8s provider | kind cert không có SAN cho public IP — giải pháp đúng cho lab |
| `apiServerPort: 6443` cố định | Tránh port random của kind, SG chỉ cần mở 1 port cụ thể |
