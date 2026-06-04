##############################################################
# outputs.tf
##############################################################

output "alb_url" {
  description = "URL của app qua ALB — mở trên browser"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_public_ip" {
  description = "IP public của EC2 (dùng để SSH debug nếu cần)"
  value       = aws_instance.k8s.public_ip
}

output "ec2_ssh_command" {
  description = "Lệnh SSH vào EC2 để debug"
  value       = "ssh -i output/${var.project_name}-key.pem ubuntu@${aws_instance.k8s.public_ip}"
}

output "k8s_deployment_status" {
  description = "Trang thai deployment trong K8s"
  value = {
    name     = kubernetes_deployment.hello.metadata[0].name
    replicas = kubernetes_deployment.hello.spec[0].replicas
    service  = kubernetes_service.hello.metadata[0].name
    nodeport = var.node_port
  }
}

output "architecture_summary" {
  description = "Tóm tắt kiến trúc"
  value       = <<-EOT
    ┌─────────────┐    HTTP:80    ┌─────────────┐    NodePort:${var.node_port}    ┌─────────────────────────────┐
    │   Browser   │ ────────────► │  AWS ALB    │ ──────────────────────► │  EC2 (Ubuntu 22.04)         │
    └─────────────┘               └─────────────┘                         │  ┌───────────────────────┐  │
                                                                           │  │  kind cluster          │  │
                                                                           │  │  └── K8s Service       │  │
                                                                           │  │       └── Pod (nginx)  │  │
                                                                           │  └───────────────────────┘  │
                                                                           └─────────────────────────────┘
    Provider 1: AWS       → VPC, EC2, ALB, SG, IAM
    Provider 2: Kubernetes → reads deployment state from kind cluster
  EOT
}
