# k8s-on-aws — Terraform + Kubernetes (minikube) trên AWS

Dự án tự động hóa **100% bằng Terraform** việc dựng một Kubernetes cluster chạy
trên EC2 và expose app ra Internet qua AWS ALB.

Điểm đặc trưng: **toàn bộ K8s lifecycle nằm trong `user_data`** — Terraform chỉ
quản lý hạ tầng AWS, không wire Kubernetes provider. App được deploy thẳng bằng
`kubectl apply` trong quá trình EC2 boot.

---

## Kiến trúc tổng quan

```
Browser :80
    │
    ▼
AWS ALB
    │
    ▼  :30080  (NodePort)
EC2 t3.medium — Ubuntu 22.04
    │
    ▼  minikube --driver=none  (bare-metal, K8s chạy trên host)
K8s Service NodePort :30080
    │
    ├──▶ Pod nginx [0]  (nginx:1.27-alpine)
    └──▶ Pod nginx [1]  (nginx:1.27-alpine)
```

### Flow expose — gói tin đi qua những gì

```
Internet
  │ :80
  ▼
ALB SG  (ingress 0.0.0.0/0 :80)
  │
  ▼
AWS ALB  →  Target Group  →  EC2 :30080
  │
  ▼
EC2 host — minikube --driver=none
  │   kube-proxy tạo iptables rule: host :30080 → Pod :80
  ▼
iptables DNAT  (kube-proxy NodePort)
  │
  ▼
nginx Pod :80
```

Khác với kind (dùng `extraPortMappings` + Docker port mapping),
minikube `--driver=none` chạy **trực tiếp trên host** — kube-proxy
viết iptables rule thẳng vào kernel của EC2, không có container hay
process relay nào ở giữa.

---

## Flow wire 4 Terraform provider

Dự án dùng **4 provider trong cùng 1 `terraform apply`**, mỗi cái
giải quyết một bài toán riêng:

```
┌─────────────────────────────────────────────────────────────┐
│  Provider 1 — hashicorp/http                                │
│                                                             │
│  data.http.my_ip                                            │
│    GET https://checkip.amazonaws.com                        │
│    → trả về public IP của máy đang chạy Terraform           │
│    → local.my_cidr = "x.x.x.x/32"                          │
│    → EC2 Security Group: SSH ingress chỉ cho IP đó          │
│      (thay vì mở 0.0.0.0/0)                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Provider 2 — hashicorp/tls                                 │
│                                                             │
│  tls_private_key.ssh  (RSA 4096, generated in-memory)       │
│    ├── public_key_openssh  → aws_key_pair.main  (lên AWS)   │
│    └── private_key_pem    → local_sensitive_file (ra .pem)  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Provider 3 — hashicorp/local                               │
│                                                             │
│  local_sensitive_file.private_key                           │
│    content  = tls_private_key.ssh.private_key_pem           │
│    filename = output/k8s-on-aws-key.pem                     │
│    file_permission = "0600"                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Provider 4 — hashicorp/aws                                 │
│                                                             │
│  VPC + 2 Subnets + IGW + Route Table                        │
│  Security Groups  (ALB SG, EC2 SG)                          │
│  EC2 instance     (Ubuntu 22.04, t3.medium, 30 GB gp3)      │
│  ALB + Target Group + Listener HTTP :80                     │
│  Key Pair         (nhận public key từ tls provider)         │
└─────────────────────────────────────────────────────────────┘
```

Thứ tự dependency:

```
data.http.my_ip
  └─▶ aws_security_group.ec2  (SSH ingress /32)

tls_private_key.ssh
  ├─▶ aws_key_pair.main
  └─▶ local_sensitive_file.private_key

aws_vpc.main
  └─▶ aws_subnet.public  ──▶  aws_instance.k8s
        └─▶ aws_lb.main  (cần >= 2 subnet AZ)
```

---

## Cơ chế minikube --driver=none

### Tại sao dùng `--driver=none`?

EC2 Linux không hỗ trợ nested virtualization cho VirtualBox/HyperV.
`--driver=none` (bare-metal mode) chạy tất cả Kubernetes components
(`kube-apiserver`, `etcd`, `kube-scheduler`, `kube-controller-manager`,
`kube-proxy`, `kubelet`) **trực tiếp như Linux process** trên EC2 host —
không cần VM driver.

### API server bind address

```
minikube start \
  --driver=none \
  --kubernetes-version=v1.30.0 \
  --extra-config=apiserver.bind-address=0.0.0.0
```

`--extra-config=apiserver.bind-address=0.0.0.0` cho phép API server
lắng nghe trên **tất cả interface** của EC2, bao gồm public IP.
Đây là lý do không cần socat hay tunnel để gọi K8s API từ ngoài.

### NodePort và iptables

Khi Service type=NodePort được tạo, kube-proxy viết rule iptables:

```
PREROUTING: tcp dpt:30080 → DNAT → ClusterIP:80
POSTROUTING: MASQUERADE
```

Packet từ ALB vào EC2 :30080 bị DNAT thẳng sang Pod IP — không đi qua
process nào, chỉ qua kernel.

### Dependencies cần có trước khi `minikube start`

`--driver=none` + Docker + K8s >= 1.24 yêu cầu:

| Dependency | Lý do |
|---|---|
| `conntrack` | kubeadm yêu cầu để track connection |
| `socat` | kubeadm port-forward |
| `crictl` | CRI tool, bắt buộc từ K8s 1.24+ |
| `cri-dockerd` | Bridge giữa Docker và CRI interface của K8s |
| Docker | Container runtime cho Pod |

---

## Cấu trúc thư mục

```
k8s-on-aws/
├── versions.tf          # Terraform + provider version constraints
├── providers.tf         # Cấu hình 4 provider
├── variables.tf         # Biến đầu vào
├── networking.tf        # VPC, 2 public subnets, IGW, Route Table
├── security_groups.tf   # ALB SG + EC2 SG (SSH giới hạn bởi http provider)
├── ec2.tf               # SSH key (tls + local) + EC2 instance
├── alb.tf               # ALB, Target Group, Listener HTTP :80
├── outputs.tf           # ALB URL, SSH command, operator IP, ...
├── templates/
│   └── user_data.sh.tpl # Bootstrap: Docker + crictl + minikube + kubectl apply
└── output/              # (tự tạo) SSH key .pem
```

---

## Các biến

| Biến | Mặc định | Mô tả |
|---|---|---|
| `aws_region` | `ap-southeast-1` | AWS region |
| `project_name` | `k8s-on-aws` | Prefix đặt tên resource |
| `instance_type` | `t3.medium` | EC2 type (tối thiểu t3.medium cho minikube) |
| `app_name` | `hello-k8s` | Tên Deployment và Service trong K8s |
| `app_replicas` | `2` | Số Pod replica |
| `node_port` | `30080` | NodePort expose app (30000–32767) |

---

## Deploy

```powershell
terraform init
terraform apply -auto-approve
```

Không có script 2-phase. Một lần apply duy nhất vì Terraform không
wire Kubernetes provider — toàn bộ K8s setup xảy ra trong `user_data`
khi EC2 boot.

**Thời gian chờ:** ~10–15 phút để EC2 boot, cài dependencies, start
minikube, pull image nginx và rollout xong.

---

## Sau khi deploy

```
alb_url       = "http://<alb-dns-name>"
ec2_public_ip = "x.x.x.x"
ssh_command   = "ssh -i output/k8s-on-aws-key.pem ubuntu@x.x.x.x"
operator_ip   = "y.y.y.y/32"   ← IP máy bạn, được phép SSH
```

Mở `alb_url` trên browser để xem app.

### Debug trên EC2

```bash
ssh -i output/k8s-on-aws-key.pem ubuntu@<ec2-ip>

# Xem log bootstrap
sudo tail -f /var/log/user_data.log

# Kiểm tra cluster
sudo kubectl get nodes
sudo kubectl get pods -n default
sudo kubectl get svc -n default

# Test port trực tiếp
curl http://localhost:30080/
```

---

## Tear down

```powershell
terraform destroy -auto-approve
```

---

## So sánh với k8s-challenge (kind)

| | k8s-on-aws (minikube) | k8s-challenge (kind) |
|---|---|---|
| K8s runtime | minikube `--driver=none` — process trên host | kind — container trên Docker |
| Port mapping | kube-proxy iptables trực tiếp trên host | Docker `extraPortMappings` → kernel |
| API server | bind `0.0.0.0:6443` trên host | bind `0.0.0.0:6443` trong container, Docker map ra host |
| Terraform K8s provider | ✗ không dùng (deploy qua user_data) | ✓ dùng (ConfigMap + Deployment + Service) |
| Số provider | 4 (aws, http, tls, local) | 6 (aws, kubernetes, tls, local, null, http) |
| SSH giới hạn | ✓ chỉ IP operator (http provider) | ✗ mở 0.0.0.0/0 |
| Phụ thuộc boot | nhiều (crictl, cri-dockerd, conntrack...) | ít (chỉ Docker) |
| Trạng thái sau reboot | ✗ minikube không tự start lại | ✗ kind container dừng lại |

### Flow expose so sánh

**k8s-on-aws (minikube):**
```
ALB :80 → EC2 :30080 → iptables (kube-proxy, kernel) → Pod :80
```

**k8s-challenge (kind):**
```
ALB :80 → EC2 :30080 → iptables (Docker port mapping, kernel)
        → kind container :30080 → iptables (kube-proxy) → Pod :80
```

Minikube ít tầng hơn vì K8s chạy trực tiếp trên host — nhưng đổi lại
cần nhiều dependencies hơn khi setup.

---

## Lưu ý

- SSH key lưu tại `output/k8s-on-aws-key.pem` — không commit lên git.
- Security group SSH ingress được giới hạn theo IP của máy chạy
  `terraform apply` tại thời điểm apply. Nếu IP thay đổi (VPN, network
  khác), chạy `terraform apply` lại để cập nhật rule.
- minikube cluster **không tự khởi động lại** sau khi EC2 reboot.
  Nếu EC2 bị reboot, cần SSH vào và chạy `sudo minikube start` lại.

---

## Stack

- **Terraform** >= 1.5 với providers: `aws ~> 5.0`, `tls ~> 4.0`, `local ~> 2.5`, `http ~> 3.4`
- **EC2**: Ubuntu 22.04 LTS, t3.medium, 30 GB gp3
- **minikube**: latest, `--driver=none`, K8s v1.30.0
- **App**: nginx:1.27-alpine, 2 replicas, ConfigMap HTML
- **AWS region**: ap-southeast-1 (Singapore)
