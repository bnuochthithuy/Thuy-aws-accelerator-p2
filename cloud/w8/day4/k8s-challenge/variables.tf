variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix cho tất cả resource"
  type        = string
  default     = "k8s-challenge"
}

variable "instance_type" {
  description = "EC2 instance type (min t3.medium cho kind)"
  type        = string
  default     = "t3.medium"
}

variable "node_port" {
  description = "NodePort expose app ra ngoài EC2 (30000-32767)"
  type        = number
  default     = 30080
}

variable "app_name" {
  description = "Tên app deploy lên K8s"
  type        = string
  default     = "hello-k8s"
}

variable "app_replicas" {
  description = "Số pod replicas"
  type        = number
  default     = 2
}
