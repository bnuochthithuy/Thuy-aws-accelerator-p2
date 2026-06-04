output "alb_url" {
  description = "URL app qua ALB — mo tren browser"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_public_ip" {
  description = "IP public cua EC2"
  value       = aws_instance.k8s.public_ip
}

output "ssh_command" {
  description = "Lenh SSH vao EC2 de debug"
  value       = "ssh -i output/${var.project_name}-key.pem ubuntu@${aws_instance.k8s.public_ip}"
}

output "kubeconfig_path" {
  description = "Path file kubeconfig local"
  value       = "${path.module}/output/kubeconfig.yaml"
}

output "k8s_info" {
  description = "Thong tin K8s deployment"
  value = {
    deployment = kubernetes_deployment.app.metadata[0].name
    replicas   = kubernetes_deployment.app.spec[0].replicas
    service    = kubernetes_service.app.metadata[0].name
    node_port  = var.node_port
  }
}

output "architecture" {
  description = "So do kien truc"
  value       = <<-EOT

    Browser :80
       |
       v
    AWS ALB  (${aws_lb.main.dns_name})
       |
       v :${var.node_port} (NodePort)
    EC2 t3.medium (${aws_instance.k8s.public_ip})
       |
       v
    kind cluster (port 6443)
       |
       v
    K8s Service (NodePort:${var.node_port})
       |
       +---> Pod nginx [0]
       +---> Pod nginx [1]

    Provider 1: aws        -> VPC, EC2, ALB, SG
    Provider 2: kubernetes -> ConfigMap, Deployment, Service
    kubeconfig: fetched via SSH -> output/kubeconfig.yaml
  EOT
}
