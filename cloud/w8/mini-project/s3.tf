##############################################################
# s3.tf — S3 Bucket for static assets
#
# Step 4: Create S3 bucket for static assets
#
# Config:
#   - Block toàn bộ public access (security best practice)
#   - Versioning bật — recover file nếu bị xóa nhầm
#   - Server-side encryption AES-256
#   - Lifecycle rule: chuyển sang STANDARD_IA sau 30 ngày
#     để tiết kiệm chi phí storage
##############################################################

# ── S3 Bucket ─────────────────────────────────────────────────
resource "aws_s3_bucket" "assets" {
  # Tên bucket phải globally unique → kết hợp project + account_id
  bucket = "${var.project_name}-${var.s3_bucket_suffix}-${data.aws_caller_identity.current.account_id}"

  tags = { Name = "${var.project_name}-assets" }
}

# ── Lấy account ID để tạo tên bucket unique ───────────────────
data "aws_caller_identity" "current" {}

# ── Block Public Access ───────────────────────────────────────
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Versioning ────────────────────────────────────────────────
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ── Server-Side Encryption (AES-256) ─────────────────────────
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ── Lifecycle Rule: STANDARD → STANDARD_IA sau 30 ngày ───────
resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ── Bucket Policy: chỉ cho phép EC2 instance truy cập ─────────
resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2RoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.assets.arn,
          "${aws_s3_bucket.assets.arn}/*"
        ]
      }
    ]
  })
}

# ── IAM Role cho EC2 để access S3 ────────────────────────────
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
