data "http" "workstation-external-ip" {
  url = "http://ipv4.icanhazip.com"
}

locals {
  workstation-external-cidr = "${chomp(data.http.workstation-external-ip.body)}/32"
}

resource "aws_security_group" "master-public-lb" {
  name_prefix = "master-public-lb-"
  description = "Master-Public-LB"
  vpc_id      = aws_vpc.main.id
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.battle}-sg-egress"
    Battle = var.battle
    Warrior   = var.warrior
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "egress" {
  name        = "${var.battle}-egress"
  description = "Allow all outgoing traffic to everywhere"
  vpc_id      = aws_vpc.main.id

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.battle}-sg-egress"
    Battle = var.battle
    Warrior   = var.warrior
  }
}

resource "aws_security_group" "ingress_internal" {
  name        = "${var.battle}-ingress-internal"
  description = "Allow all incoming traffic from nodes and Pods in the cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    self        = true
    description = "Allow incoming traffic from cluster nodes"

  }
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = null
    description = "Allow incoming traffic from the Pods of the cluster"
  }

  tags = {
    Name      = "${var.battle}-sg-ingress-internal"
    Battle    = var.battle
    Warrior   = var.warrior
  }
}

resource "aws_security_group" "ingress_k8s" {
  name        = "${var.battle}-ingress-k8s"
  description = "Allow incoming Kubernetes API requests (TCP/6443) from outside the cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.battle}-sg-ingress-internal"
    Battle    = var.battle
    Warrior   = var.warrior
  }
}

resource "aws_security_group" "ingress_ssh" {
  name        = "${var.battle}-ingress-ssh"
  description = "Allow incoming SSH traffic (TCP/22) from outside the cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [local.workstation-external-cidr]
  }

  tags = {
    Name      = "${var.battle}-sg-ingress-internal"
    Battle    = var.battle
    Warrior   = var.warrior
  }
}