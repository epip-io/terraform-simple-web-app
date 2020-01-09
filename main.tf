provider "aws" {
  region = var.region
}

locals {
  user_data = <<-USER_DATA
    #!/usr/bin/env bash
    mkdir -p /opt/flaskapp

    echo "${file("app.py")}" > /opt/flaskapp/app.py
    echo "${file("app.service")}" > /etc/systemd/system/app.service

    apt-get update && apt-get install python-pip -y

    pip install flask

    systemctl enable app
    systemctl start app
  USER_DATA

  instance_count       = var.instance_enabled ? 1 : 0
  security_group_count = var.create_default_security_group ? 1 : 0
  region               = var.region != "" ? var.region : data.aws_region.default.name
  root_iops            = var.root_volume_type == "io1" ? var.root_iops : "0"
  availability_zone    = var.availability_zone != "" ? var.availability_zone : data.aws_subnet.default.availability_zone
  ami                  = var.ami != "" ? var.ami : data.aws_ami.default.image_id
  ami_owner            = var.ami != "" ? var.ami_owner : data.aws_ami.default.owner_id
  root_volume_type     = var.root_volume_type != "" ? var.root_volume_type : data.aws_ami.info.root_device_type
  public_dns           = join("", aws_instance.default.*.public_dns)
}

module "aws_key_pair" {
  source              = "git::https://github.com/cloudposse/terraform-aws-key-pair.git?ref=tags/0.4.0"
  namespace           = var.namespace
  stage               = var.stage
  name                = var.name
  ssh_public_key_path = var.ssh_public_key_path
  generate_ssh_key    = true
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.7.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  cidr_block = "172.16.0.0/16"
}

module "subnets" {
  source               = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.16.0"
  availability_zones   = var.availability_zones
  namespace            = var.namespace
  stage                = var.stage
  name                 = var.name
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = false
  nat_instance_enabled = false
}

data "aws_caller_identity" "default" {
}

data "aws_region" "default" {
}

data "aws_subnet" "default" {
  id = module.subnets.private_subnet_ids[0]
}

data "aws_iam_policy_document" "default" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

data "aws_ami" "default" {
  most_recent = "true"

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "aws_ami" "info" {
  filter {
    name   = "image-id"
    values = [local.ami]
  }

  owners = [local.ami_owner]
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.14.1"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = var.attributes
  delimiter  = var.delimiter
  enabled    = var.instance_enabled
  tags       = var.tags
}

resource "aws_instance" "default" {
  count                       = local.instance_count
  ami                         = local.ami
  availability_zone           = local.availability_zone
  instance_type               = var.instance_type
  user_data_base64            = base64encode(local.user_data)
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = module.aws_key_pair.key_name
  subnet_id                   = module.subnets.public_subnet_ids[0]
  monitoring                  = false

  vpc_security_group_ids = compact(
    concat(
      [
        var.create_default_security_group ? join("", aws_security_group.default.*.id) : "",
      ],
      [ module.vpc.vpc_default_security_group_id ]
    )
  )

  root_block_device {
    volume_type           = local.root_volume_type
    volume_size           = var.root_volume_size
    iops                  = local.root_iops
    delete_on_termination = var.delete_on_termination
  }

  tags = module.label.tags
}

resource "aws_security_group" "default" {
  count       = local.security_group_count
  name        = module.label.id
  vpc_id      = module.vpc.vpc_id
  description = "Instance default security group (only egress access is allowed)"
  tags        = module.label.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "egress" {
  count             = var.create_default_security_group ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default[0].id
}

resource "aws_security_group_rule" "ingress" {
  count             = var.create_default_security_group ? length(compact(var.allowed_ports)) : 0
  type              = "ingress"
  from_port         = var.allowed_ports[count.index]
  to_port           = var.allowed_ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default[0].id
}
