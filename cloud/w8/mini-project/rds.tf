##############################################################
# rds.tf — RDS MySQL in private subnet
#
# Step 3: Deploy RDS MySQL in private subnet
#
# RDS nằm trong private subnets — không có public IP
# Chỉ EC2 web server (qua security group) mới kết nối được
# Dùng DB subnet group spanning 2 AZ (best practice / bắt buộc)
##############################################################

# ── DB Subnet Group — bắt buộc phải có >= 2 AZ ───────────────
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Private subnets for RDS MySQL"
  subnet_ids  = module.vpc.private_subnet_ids

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

# ── RDS MySQL Instance ─────────────────────────────────────────
resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql"

  # Engine
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 100 # autoscaling storage up to 100 GB
  storage_type          = "gp3"
  storage_encrypted     = true

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network — đặt trong private subnets, KHÔNG có public access
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false # set true cho production

  # Maintenance
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  deletion_protection     = false # set true cho production

  # Bỏ qua final snapshot khi destroy (lab env)
  skip_final_snapshot = true

  tags = { Name = "${var.project_name}-mysql" }
}
