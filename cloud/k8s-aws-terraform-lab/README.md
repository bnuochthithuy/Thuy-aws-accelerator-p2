# K8s on AWS — Terraform 1-Click

## Architecture

```text
Browser -> AWS ALB :80 -> Target Group -> EC2 :30080 -> kind Kubernetes Cluster -> Service NodePort -> nginx Deployment
```

## Providers

This project uses 2 Terraform providers:

1. `aws`: creates EC2, Security Groups, ALB, Target Group, Listener.
2. `null`: runs a local-exec step after infrastructure is created.

## Requirements

- AWS account
- AWS Access Key configured
- Terraform installed
- Existing EC2 Key Pair in `ap-southeast-1`

## Configure AWS credentials

```bash
aws configure
```

Region:

```bash
ap-southeast-1
```

## Run

Create file `terraform.tfvars`:

```hcl
key_name = "YOUR_KEY_PAIR_NAME"
my_ip    = "YOUR_PUBLIC_IP/32"
```

Then run:

```bash
terraform init
terraform apply
```

After apply finishes, wait 3-5 minutes and open:

```bash
terraform output alb_url
```

Expected result: nginx welcome page.

## Verify Kubernetes

SSH to EC2:

```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

Check:

```bash
sudo kubectl get nodes
sudo kubectl get pods
sudo kubectl get svc
```

## Destroy

```bash
terraform destroy
```
