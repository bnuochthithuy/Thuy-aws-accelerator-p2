# K8s on AWS — Terraform 1-Click

> Dựng EC2 + kind cluster + deploy app + expose qua ALB  
> **Toàn bộ bằng 1 lệnh `terraform apply`**

---

## Sơ Đồ Kiến Trúc

```
Internet
    │ HTTP :80
    ▼
┌─────────────────┐
│    AWS ALB      │  (2 public subnets, 2 AZ)
└────────┬────────┘
         │ HTTP :30080 (NodePort)
         ▼
┌──────────────────────────────────────────┐
│  EC2 t3.medium (Ubuntu 22.04)            │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │  kind cluster  (Docker-in-Docker)  │  │
│  │                                    │  │
│  │  ┌──────────────────────────────┐  │  │
│  │  │  K8s Service (NodePort)      │  │  │
│  │  │    └── Deployment (2 pods)   │  │  │
│  │  │          └── nginx:alpine    │  │  │
│  │  └──────────────────────────────┘  │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

---

## Cách Wire Provider (≥2 Provider)

| Provider | Role |
|---|---|
| `hashicorp/aws` | Dựng VPC, EC2, ALB, IAM, SG |
| `hashicorp/kubernetes` | Wire vào kind cluster để read K8s state |
| `hashicorp/tls` | Tạo SSH key pair tự động |
| `hashicorp/local` | Lưu private key ra file `.pem` |

**Cơ chế wire Kubernetes provider:**

```
EC2 user_data
  → cài kind, deploy app
  → push kubeconfig lên SSM Parameter Store (SecureString)

Terraform
  → data.aws_ssm_parameter.kubeconfig (chờ sau 3 phút)
  → kubernetes provider đọc host/token/ca từ kubeconfig đó
  → kubernetes resources/data sources chạy trong cùng apply
```

Thứ tự phụ thuộc:
```
aws_instance → time_sleep → data.aws_ssm_parameter → kubernetes provider → k8s resources
```

---

## Yêu Cầu Trước Khi Chạy

- Terraform >= 1.5.0
- AWS CLI đã configure (`aws configure` hoặc env vars)
- Quyền IAM: EC2, VPC, ALB, IAM, SSM

---

## 1-Click Deploy

```bash
# Clone/vào thư mục project
cd cloud/w8/day4/k8s-on-aws

# 1. Init providers
terraform init

# 2. (Tùy chọn) Xem trước
terraform plan

# 3. Deploy toàn bộ — 1 lệnh
terraform apply -auto-approve
```

Sau ~5–7 phút, output sẽ in ra:

```
alb_url = "http://hello-k8s-alb-xxxxxxxxx.ap-southeast-1.elb.amazonaws.com"
```

Mở URL đó trên browser → thấy trang "Xin Chào Bạn Bè!" ✅

---

## Kiểm Tra Sau Deploy

```bash
# Xem tất cả outputs
terraform output

# SSH vào EC2 debug (nếu cần)
ssh -i output/hello-k8s-key.pem ubuntu@<EC2_IP>

# Trên EC2: kiểm tra kind cluster
kubectl get nodes
kubectl get pods
kubectl get svc
```

---

## Dọn Dẹp (Destroy)

```bash
terraform destroy -auto-approve
```

Xóa sạch toàn bộ hạ tầng, không tốn tiền sau khi xong.

---

## Giải Thích Thiết Kế

**Tại sao dùng kind thay minikube?**  
kind chạy trong Docker không cần VM driver — phù hợp EC2 Linux hơn, nhẹ hơn, startup nhanh hơn (~90s vs ~3–5 phút).

**Tại sao dùng NodePort thay Ingress/LoadBalancer?**  
Đơn giản nhất để wire ALB với 1 EC2: ALB forward thẳng vào NodePort. Không cần cài ingress-nginx hay cloud-provider.

**Tại sao dùng SSM để truyền kubeconfig?**  
EC2 không có IP fixed lúc Terraform plan. Dùng SSM làm "mailbox" — EC2 push kubeconfig sau khi kind sẵn sàng, Terraform đọc lại. Không cần hardcode IP, không cần remote-exec (an toàn hơn, không cần mở SSH).

**Tại sao `time_sleep` 3 phút?**  
`user_data` chạy bất đồng bộ. Terraform cần chờ EC2 cài xong Docker + kind + deploy app trước khi đọc SSM. Thời gian thực ~3–4 phút trên t3.medium.
