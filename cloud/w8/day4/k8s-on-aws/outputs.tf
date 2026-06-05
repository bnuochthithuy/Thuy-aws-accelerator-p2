##############################################################
# outputs.tf
##############################################################

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

output "operator_ip" {
  description = "IP cua may dang chay Terraform (duoc http provider lay tu checkip.amazonaws.com)"
  value       = local.my_cidr
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
  EC2 t3.medium Ubuntu 22.04 (${aws_instance.k8s.public_ip})
      |
      v
  minikube cluster (--driver=none, bare-metal)
      |
      v
  K8s Service NodePort:${var.node_port}
      |
      +---> Pod nginx [0]
      +---> Pod nginx [1]

  Provider wire:
    http  -> checkip.amazonaws.com -> SSH ingress /32
    tls   -> RSA 4096 key -> aws_key_pair + local .pem
    local -> ghi private key output/*.pem (0600)
    aws   -> VPC, EC2, ALB, SG, Key Pair
  EOT
}
