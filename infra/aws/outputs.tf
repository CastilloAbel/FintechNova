output "public_ip" {
  description = "Public IPv4 address used by the deploy job."
  value       = aws_instance.app.public_ip
}

output "instance_id" {
  description = "Created EC2 instance ID."
  value       = aws_instance.app.id
}

output "ssh_user" {
  description = "Amazon Linux 2023 default SSH user."
  value       = "ec2-user"
}

output "ssh_public_key" {
  description = "Public key stored in AWS; used by the destroy job to satisfy the configuration input."
  value       = var.ssh_public_key
}

output "ami_id" {
  description = "AMI used by the instance."
  value       = var.ami_id
}

output "runner_ssh_cidr" {
  description = "SSH ingress CIDR configured on the security group."
  value       = var.runner_ssh_cidr
}

output "resource_suffix" {
  description = "Suffix used in unique key-pair and security-group names."
  value       = var.resource_suffix
}
