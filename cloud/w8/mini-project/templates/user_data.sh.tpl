#!/bin/bash
##############################################################
# user_data.sh.tpl — Bootstrap EC2 web server
#
# Cài nginx, cấu hình trang index với thông tin kết nối
##############################################################
set -euxo pipefail

# ── Cập nhật và cài nginx ─────────────────────────────────────
apt-get update -y
apt-get install -y nginx mysql-client curl unzip

# ── Trang web demo ─────────────────────────────────────────────
cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${project_name} — Web App</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
    h1   { color: #232f3e; }
    .badge { display:inline-block; background:#ff9900; color:#fff; padding:4px 10px; border-radius:4px; margin:4px; }
    .info  { background:#f8f8f8; border-left:4px solid #ff9900; padding:12px; margin:10px 0; }
  </style>
</head>
<body>
  <h1>🚀 ${project_name} — Final Project</h1>
  <p>Web App deployed on AWS with Terraform</p>

  <h2>Architecture</h2>
  <span class="badge">VPC</span>
  <span class="badge">Public Subnet</span>
  <span class="badge">Private Subnet</span>
  <span class="badge">EC2 (nginx)</span>
  <span class="badge">RDS MySQL</span>
  <span class="badge">S3</span>

  <div class="info">
    <strong>DB Host:</strong> ${db_host}<br>
    <strong>DB Name:</strong> ${db_name}<br>
    <strong>S3 Bucket:</strong> ${s3_bucket}
  </div>

  <p>✅ Security Groups configured — only required traffic allowed</p>
</body>
</html>
HTML

# ── Cấu hình nginx ─────────────────────────────────────────────
systemctl enable nginx
systemctl start nginx

echo "Bootstrap complete — nginx is running"
