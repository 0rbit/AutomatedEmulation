# Ubuntu 24.04 endpoint. Operator SSH is limited to the detected ISP address.
# The BAS server and this instance can reach each other on all ports.

variable "ubuntu1_instance_type" {
  description = "The AWS instance type to use for ubuntu1."
  default     = "t3.medium"
}

data "aws_ami" "ubuntu1" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "ubuntu1" {
  name        = "ubuntu1"
  description = "Operator SSH and BAS traffic for ubuntu1"
  vpc_id      = aws_vpc.operator.id

  ingress {
    description      = "SSH from operator ISP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [local.src_ip]
    ipv6_cidr_blocks = local.ipv6_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ubuntu1"
  }
}

resource "aws_security_group_rule" "ubuntu1_ingress_from_bas" {
  description              = "All traffic from the BAS server"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.ubuntu1.id
  source_security_group_id = aws_security_group.bas_allow_all_internal.id
}

resource "aws_security_group_rule" "bas_ingress_from_ubuntu1" {
  description              = "All traffic from ubuntu1"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.bas_allow_all_internal.id
  source_security_group_id = aws_security_group.ubuntu1.id
}

resource "aws_instance" "ubuntu1" {
  ami                         = data.aws_ami.ubuntu1.id
  instance_type               = var.ubuntu1_instance_type
  subnet_id                   = aws_subnet.user_subnet.id
  key_name                    = module.key_pair.key_pair_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ubuntu1.id]

  tags = {
    Name = "ubuntu1"
  }
}

output "ubuntu1_details" {
  value = <<EOS
-------------------------
Virtual Machine ubuntu1
-------------------------
Instance ID: ${aws_instance.ubuntu1.id}
Private IP: ${aws_instance.ubuntu1.private_ip}
Public IP:  ${aws_instance.ubuntu1.public_ip}

SSH
---
ssh -i ssh_key.pem ubuntu@${aws_instance.ubuntu1.public_ip}

EOS
}
