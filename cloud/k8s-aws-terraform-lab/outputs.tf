output "alb_url" {
  description = "Open this URL in browser after 3-5 minutes"
  value       = "http://${aws_lb.app.dns_name}"
}

output "ec2_public_ip" {
  description = "EC2 public IP"
  value       = aws_instance.k8s.public_ip
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.k8s.public_ip}"
}
