# Final Project: Deploy a Web App on AWS

## Architecture

```
Internet
    │ :80 / :443
    ▼
┌─────────────────────────────────────────────┐
│              VPC (10.20.0.0/16)             │
│                                             │
│  ┌──────────────────────────────────────┐   │
│  │         Public Subnet                │   │
│  │  ┌────────────────────────────────┐  │   │
│  │  │  EC2 (nginx web server)        │  │   │
│  │  │  SG: :80/:443 open             │  │   │
│  │  │      :22 → operator IP only    │  │   │
│  │  └────────────────────────────────┘  │   │
│  │  ┌──────────────┐                    │   │
│  │  │ NAT Gateway  │ ← EIP              │   │
│  │  └──────┬───────┘                    │   │
│  └─────────┼────────────────────────────┘   │
│            │                                │
│  ┌─────────▼────────────────────────────┐   │
│  │         Private Subnet               │   │
│  │  ┌────────────────────────────────┐  │   │
│  │  │  RDS MySQL 8.0                 │  │   │
│  │  │  SG: :3306 from web-sg ONLY    │  │   │
│  │  └────────────────────────────────┘  │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘

S3 Bucket (static assets) — public access BLOCKED
         ↑ access via IAM Role từ EC2
```

## Files

| File | Mô tả |
|------|-------|
| `versions.tf` | Provider requirements |
| `providers.tf` | AWS / http / tls / local providers |
| `variables.tf` | Tất cả input variables |
| `networking.tf` | Gọi module VPC |
| `security_groups.tf` | SG cho EC2 và RDS |
| `ec2.tf` | SSH key pair + EC2 web server |
| `rds.tf` | RDS MySQL in private subnet |
| `s3.tf` | S3 bucket + IAM role cho EC2 |
| `outputs.tf` | Outputs sau khi apply |
| `modules/vpc/` | VPC module (reusable) |
| `templates/user_data.sh.tpl` | Bootstrap nginx trên EC2 |

## Steps

### 1. Init

```bash
terraform init
```

### 2. Plan (xem trước)

```bash
# Truyền DB password qua env var — không hardcode trong tfvars
$env:TF_VAR_db_password = "YourSecurePassword123!"
terraform plan
```

### 3. Apply

```bash
terraform apply
```

### 4. SSH vào EC2

```bash
# Output ssh_command sẽ in ra lệnh SSH chính xác sau khi apply
ssh -i output/webapp-key.pem ubuntu@<ec2_public_ip>
```

### 5. Kết nối RDS từ EC2

```bash
# Chạy từ bên trong EC2
mysql -h <rds_endpoint> -u admin -p appdb
```

### 6. Destroy

```bash
terraform destroy
```

## Security Notes

- RDS nằm trong **private subnet** — không có public IP, không thể truy cập trực tiếp từ Internet
- Security group RDS chỉ cho phép port 3306 từ **web-sg** (EC2 security group)
- SSH EC2 chỉ mở từ **IP của máy đang chạy Terraform** (tự động lấy qua http provider)
- S3 bucket **block public access** hoàn toàn — chỉ EC2 IAM role mới đọc/ghi được
- EBS root volume và RDS storage đều bật **encryption**
- DB password nên dùng `TF_VAR_db_password` env var thay vì commit vào git
