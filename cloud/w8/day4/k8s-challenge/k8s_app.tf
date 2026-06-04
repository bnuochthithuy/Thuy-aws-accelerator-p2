##############################################################
# k8s_app.tf — Kubernetes resources (Provider 2)
#
# Terraform quản lý trực tiếp:
#   ConfigMap  → nội dung HTML trang app
#   Deployment → 2 nginx pod mount HTML từ ConfigMap
#   Service    → NodePort expose ra port 30080
#
# Tất cả phụ thuộc vào data.aws_ssm_parameter.kubeconfig
# → đảm bảo EC2 + kind đã sẵn sàng trước khi apply
##############################################################

# ── ConfigMap: HTML content ───────────────────────────────────
resource "kubernetes_config_map" "html" {
  depends_on = [null_resource.fetch_kubeconfig]

  metadata {
    name      = "${var.app_name}-html"
    namespace = "default"
  }

  data = {
    "index.html" = <<-HTML
      <!DOCTYPE html>
      <html lang="vi">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>K8s Challenge</title>
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
          }
          .card {
            text-align: center;
            padding: 60px 50px;
            background: rgba(255,255,255,0.06);
            border-radius: 24px;
            border: 1px solid rgba(255,255,255,0.12);
            max-width: 620px;
            width: 90%;
            backdrop-filter: blur(12px);
            box-shadow: 0 30px 60px rgba(0,0,0,0.4);
          }
          .icon { font-size: 72px; margin-bottom: 20px; }
          h1 {
            font-size: 2.6rem;
            font-weight: 700;
            color: #ffd200;
            margin-bottom: 14px;
          }
          .sub {
            font-size: 1.1rem;
            color: #a8d8ea;
            line-height: 1.7;
            margin-bottom: 10px;
          }
          .note {
            font-size: 0.9rem;
            color: #aaa;
            margin-bottom: 28px;
          }
          .badges { display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; }
          .badge {
            background: rgba(255,210,0,0.12);
            border: 1px solid #ffd200;
            color: #ffd200;
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 0.82rem;
          }
          .divider {
            border: none;
            border-top: 1px solid rgba(255,255,255,0.1);
            margin: 28px 0;
          }
          .stack { font-size: 0.8rem; color: #777; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">&#x2638;&#xFE0F;</div>
          <h1>Xin Chao Ban Be!</h1>
          <p class="sub">
            App dang chay trong <strong>Kubernetes (kind)</strong><br/>
            tren EC2 &#x2192; expose qua <strong>AWS ALB</strong>
          </p>
          <p class="note">Tu dong hoa 100% bang Terraform &#x1F680; Khong lam tay.</p>
          <div class="badges">
            <span class="badge">&#x2638; Kubernetes</span>
            <span class="badge">&#x26A1; kind</span>
            <span class="badge">&#x2601; AWS ALB</span>
            <span class="badge">&#x1F527; Terraform IaC</span>
            <span class="badge">&#x1F4E6; nginx</span>
          </div>
          <hr class="divider"/>
          <p class="stack">EC2 t3.medium &#x2022; Ubuntu 22.04 &#x2022; kind v0.23 &#x2022; K8s v1.30</p>
        </div>
      </body>
      </html>
    HTML
  }
}

# ── Deployment: 2 nginx pod ───────────────────────────────────
resource "kubernetes_deployment" "app" {
  depends_on = [
    null_resource.fetch_kubeconfig,
    kubernetes_config_map.html,
  ]

  metadata {
    name      = var.app_name
    namespace = "default"
    labels    = { app = var.app_name, "managed-by" = "terraform" }
  }

  spec {
    replicas = var.app_replicas

    selector {
      match_labels = { app = var.app_name }
    }

    template {
      metadata {
        labels = { app = var.app_name }
      }

      spec {
        container {
          name  = var.app_name
          image = "nginx:1.27-alpine"

          port {
            container_port = 80
          }

          # Readiness probe — chỉ nhận traffic khi nginx sẵn sàng
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }

          # Liveness probe — restart nếu nginx bị treo
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          # Resource requests/limits (yêu cầu của HPA nếu cần sau này)
          resources {
            requests = { cpu = "50m",  memory = "64Mi"  }
            limits   = { cpu = "200m", memory = "128Mi" }
          }

          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.html.metadata[0].name
          }
        }
      }
    }
  }
}

# ── Service: NodePort ─────────────────────────────────────────
resource "kubernetes_service" "app" {
  depends_on = [null_resource.fetch_kubeconfig]

  metadata {
    name      = "${var.app_name}-svc"
    namespace = "default"
  }

  spec {
    selector = { app = var.app_name }
    type     = "NodePort"

    port {
      port        = 80
      target_port = 80
      node_port   = var.node_port
    }
  }
}
