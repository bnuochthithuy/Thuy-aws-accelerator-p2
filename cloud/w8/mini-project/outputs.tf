##############################################################
# outputs.tf
##############################################################

output "vpc_id" {
  description = "ID của VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "ID của các public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "ID của các private subnets"
  value       = module.vpc.private_subnet_ids
}

output "ec2_public_ip" {
  description = "Public IP của web server EC2"
  value       = aws_instance.web.public_ip
}

output "ec2_web_url" {
  description = "URL HTTP của web server"
  value       = "http://${aws_instance.web.public_ip}"
}

output "ssh_command" {
  description = "Lệnh SSH vào EC2 để debug"
  value       = "ssh -i output/${var.project_name}-key.pem ubuntu@${aws_instance.web.public_ip}"
}

output "rds_endpoint" {
  description = "Endpoint kết nối RDS MySQL (từ EC2 trong VPC)"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "Port MySQL"
  value       = aws_db_instance.mysql.port
}

output "s3_bucket_name" {
  description = "Tên S3 bucket chứa static assets"
  value       = aws_s3_bucket.assets.bucket
}

output "operator_ip" {
  description = "IP của máy đang chạy Terraform (SSH ingress cho phép IP này)"
  value       = local.my_cidr
}

output "architecture_summary" {
  description = "Tóm tắt kiến trúc"
  value       = <<-EOT

  ┌─────────────────────────────────────────────────────────┐
  │              ${var.project_name} — Final Project Architecture          │
  └─────────────────────────────────────────────────────────┘

  Internet
      │ :80 / :443
      ▼
  EC2 Web Server (nginx)          Public Subnet
  IP: ${aws_instance.web.public_ip}
  SG: HTTP/HTTPS open, SSH → ${local.my_cidr} only
      │
      │ :3306 (MySQL)
      ▼
  RDS MySQL 8.0                   Private Subnet
  Host: ${aws_db_instance.mysql.address}
  SG: port 3306 from web-sg ONLY
      
  S3 Bucket (static assets)       Global
  Name: ${aws_s3_bucket.assets.bucket}
  Access: EC2 IAM Role only, public access BLOCKED

  EOT
}
