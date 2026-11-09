provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

locals {
  subnet_id = sort(data.aws_subnets.default.ids)[0]
}

resource "aws_key_pair" "deploy" {
  key_name   = "fintech-nova-${var.resource_suffix}"
  public_key = var.ssh_public_key

  tags = {
    Name      = "FinTech Nova ${var.resource_suffix}"
    ManagedBy = "Terraform"
  }
}

resource "aws_security_group" "app" {
  name_prefix = "fintech-nova-${var.resource_suffix}-"
  description = "FinTech Nova EC2: SSH from the GitLab runner and public HTTPS only."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "GitLab runner SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.runner_ssh_cidr]
  }

  ingress {
    description = "Public HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound access for package installation, image transfer, and application integrations"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "FinTech Nova ${var.resource_suffix}"
    ManagedBy = "Terraform"
  }
}

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deploy.key_name
  vpc_security_group_ids      = [aws_security_group.app.id]

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name       = "FinTech Nova"
    ManagedBy  = "Terraform"
    PipelineID = var.resource_suffix
  }
}
