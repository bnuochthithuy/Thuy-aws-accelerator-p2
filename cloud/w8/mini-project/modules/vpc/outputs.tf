##############################################################
# modules/vpc/outputs.tf
##############################################################

output "vpc_id" {
  description = "ID của VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "List ID của các public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List ID của các private subnets"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr" {
  description = "CIDR block của VPC"
  value       = aws_vpc.this.cidr_block
}
