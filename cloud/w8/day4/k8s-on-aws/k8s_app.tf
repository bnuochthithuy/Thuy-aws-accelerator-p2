##############################################################
# k8s_app.tf — Kubernetes resources qua kubernetes provider
#
# Provider thứ 2 (kubernetes) wire vào kind cluster trên EC2.
# Terraform quản lý trực tiếp K8s Deployment + Service.
# user_data chỉ setup kind cluster; app được Terraform deploy.
#
# Thứ tự phụ thuộc:
#   aws_instance → time_sleep → data.aws_ssm_parameter
#   → providers.tf kubernetes config → resources bên dưới
##############################################################

resource "kubernetes_namespace" "app" {
  depends_on = [data.aws_ssm_parameter.kubeconfig]

  metadata {
    name = "default"
    labels = {
      managed-by = "terraform"
    }
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_config_map" "html" {
  depends_on = [data.aws_ssm_parameter.kubeconfig]

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
        <title>Xin Chao Ban Be!</title>
        <style>
          body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #1a1a2e, #0f3460);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            margin: 0;
          }
          .card {
            text-align: center;
            padding: 60px 50px;
            background: rgba(255,255,255,0.07);
            border-radius: 20px;
            border: 1px solid rgba(255,255,255,0.15);
            max-width: 600px;
            width: 90%;
          }
          h1 {
            font-size: 2.8rem;
            margin-bottom: 16px;
            color: #ffd200;
          }
          p { font-size: 1.1rem; color: #a8d8ea; line-height: 1.7; }
          .badge {
            display: inline-block;
            background: rgba(247,151,30,0.15);
            border: 1px solid #f7971e;
            color: #f7971e;
            padding: 5px 14px;
            border-radius: 20px;
            font-size: 0.82rem;
            margin: 4px;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div style="font-size:64px">&#x1F44B;</div>
          <h1>Xin Chao Ban Be!</h1>
          <p>Ung dung dang chay trong <strong>Kubernetes (kind)</strong>
             tren EC2 va duoc expose ra Internet qua <strong>AWS ALB</strong>.</p>
          <p style="margin-top:10px;color:#ccc;font-size:0.9rem">
            Tu dong hoa 100% bang Terraform - khong lam tay &#x1F680;
          </p>
          <div style="margin-top:24px">
            <span class="badge">&#x2638;&#xFE0F; Kubernetes</span>
            <span class="badge">&#x2601;&#xFE0F; AWS ALB</span>
            <span class="badge">&#x26A1; kind</span>
            <span class="badge">&#x1F527; Terraform IaC</span>
          </div>
        </div>
      </body>
      </html>
    HTML
  }
}

resource "kubernetes_deployment" "hello" {
  depends_on = [
    data.aws_ssm_parameter.kubeconfig,
    kubernetes_config_map.html,
  ]

  metadata {
    name      = var.app_name
    namespace = "default"
    labels = {
      app        = var.app_name
      managed-by = "terraform"
    }
  }

  spec {
    replicas = var.app_replicas

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.app_name
        }
      }

      spec {
        container {
          name  = var.app_name
          image = "nginx:1.27-alpine"

          port {
            container_port = var.app_port
          }

          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
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

resource "kubernetes_service" "hello" {
  depends_on = [data.aws_ssm_parameter.kubeconfig]

  metadata {
    name      = "${var.app_name}-svc"
    namespace = "default"
  }

  spec {
    selector = {
      app = var.app_name
    }

    type = "NodePort"

    port {
      port        = var.app_port
      target_port = var.app_port
      node_port   = var.node_port
    }
  }
}
