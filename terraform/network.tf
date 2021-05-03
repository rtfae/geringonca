
## AWS region's Availabililty Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# AWS VPC
resource "aws_vpc" "main" {
  cidr_block                       = var.aws_vpc_cidr
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name    = "${var.battle}-vpc"
    Battle = var.battle
    Warrior   = var.warrior
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = var.availability_zones
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.aws_vpc_cidr, 8, count.index + 11)

  tags = {
    Name      = "${var.battle}-public-${count.index}"
    Attribute = "public"
    Battle = var.battle
    Warrior   = var.warrior
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count                   = var.availability_zones
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.aws_vpc_cidr, 8, count.index + 1)
  map_public_ip_on_launch = false

  tags = {
    Name      = "${var.battle}-private-${count.index}"
    Attribute = "private"
    Battle = var.battle
    Warrior   = var.warrior
  }
}


# AWS Elastic IP addresses (EIP) for NAT Gateways
resource "aws_eip" "nat" {
  count = var.availability_zones

  vpc = true

  tags = {
    Name    = "${var.battle}-eip-natgw-${count.index}"
    Battle  = var.battle
    Warrior = var.warrior
  }
}

# AWS NAT Gateways
resource "aws_nat_gateway" "natgw" {
  count = var.availability_zones

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = element(aws_subnet.public.*.id, count.index)

  tags = {
    Name    = "${var.battle}-natgw-${count.index}"
    Battle  = var.battle
    Warrior = var.warrior
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.battle}-igw"
    Battle  = var.battle
    Warrior = var.warrior
  }
}

# AWS Route Tables
## Public
resource "aws_route_table" "rt-public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name      = "${var.battle}-rt-public"
    Attribute = "public"
    Battle  = var.battle
    Warrior = var.warrior
  }
}

## Private
resource "aws_route_table" "rt-private" {
  count  = var.availability_zones
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw[count.index].id
  }

  tags = {
    Name      = "${var.battle}-rt-private"
    Attribute = "private"
    Battle  = var.battle
    Warrior = var.warrior
  }
}


# AWS Route Table Associations
## Public
resource "aws_route_table_association" "public-rtassoc" {
  count          = var.availability_zones
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.rt-public.id
}

## Private
resource "aws_route_table_association" "private-rtassoc" {
  count          = var.availability_zones
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.rt-private[count.index].id
}

resource "aws_elb" "master-public" {
  name_prefix     = "master"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.ingress_ssh.id]

  listener {
    instance_port     = 6443
    instance_protocol = "tcp"
    lb_port           = 6443
    lb_protocol       = "tcp"
  }
  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

  tags = {
    Name      = "${var.battle}-master--publiclb"
    Attribute = "public"
    Battle  = var.battle
    Warrior = var.warrior
  }
}