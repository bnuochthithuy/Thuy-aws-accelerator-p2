variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "key_name" {
  description = "Existing AWS EC2 Key Pair name"
  type        = string
}

variable "my_ip" {
  description = "Your public IP for SSH, example: 113.x.x.x/32"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.medium"
}
