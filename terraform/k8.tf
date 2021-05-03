data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
resource "aws_key_pair" "ssh" {
  count      = var.aws_key_pair_name == null ? 1 : 0
  key_name   = "${var.warrior}-${var.battle}"
  public_key = file(var.ssh_public_key_path)
}

# resource "aws_instance" "master-god" {
#   ami           = data.aws_ami.ubuntu.image_id
#   instance_type = var.master_instance_type
#   subnet_id     = aws_subnet.public.*.id
#   key_name      = var.aws_key_pair_name == null ? aws_key_pair.ssh.0.key_name : var.aws_key_pair_name
#   vpc_security_group_ids = [
#     aws_security_group.egress.id,
#     aws_security_group.ingress_internal.id,
#     aws_security_group.ingress_k8s.id,
#     aws_security_group.ingress_ssh.id
#   ]

#   tags = {
#     Name      = "${var.battle}-master-god"
#     Attribute = "private"
#     Battle = var.battle
#     Warrior   = var.warrior
#   }

#   user_data = templatefile("${path.module}/userdata-master.tpl", {
#     domain = var.hosted_zone,
#     token = local.token,
#     cluser_name = var.battlefield,
#   })
# }

# #------------------------------------------------------------------------------#
# # Elastic IP for master node
# #------------------------------------------------------------------------------#

# # EIP for master node because it must know its public IP during initialisation
# resource "aws_eip" "master" {
#   vpc  = true
#   tags = {
#     Name      = "${var.battle}-eip"
#     Battle    = var.battle
#     Warrior   = var.warrior
#   }
# }

# resource "aws_eip_association" "master" {
#   allocation_id = aws_eip.master.id
#   instance_id   = aws_instance.master.id
# }

#------------------------------------------------------------------------------#
# Bootstrap token for kubeadm
#------------------------------------------------------------------------------#

# Generate bootstrap token
# See https://kubernetes.io/docs/reference/access-authn-authz/bootstrap-tokens/
resource "random_string" "token_id" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "token_secret" {
  length  = 16
  special = false
  upper   = false
}

locals {
  token = "${random_string.token_id.result}.${random_string.token_secret.result}"
}

## Kubernetes Master
resource "aws_launch_configuration" "master" {
  depends_on                  = [aws_key_pair.ssh]
  name_prefix                 = "master-"
  image_id                    = data.aws_ami.ubuntu.id
  instance_type               = var.master_instance_type
  security_groups             = [
    aws_security_group.egress.id,
    aws_security_group.ingress_internal.id,
    aws_security_group.ingress_k8s.id,
    aws_security_group.ingress_ssh.id
  ]
  key_name                    = var.aws_key_pair_name == null ? aws_key_pair.ssh.0.key_name : var.aws_key_pair_name
  associate_public_ip_address = true
  ebs_optimized               = true
  enable_monitoring           = true
  iam_instance_profile        = aws_iam_instance_profile.etcd_worker_master.id
  
  
  user_data = templatefile("${path.module}/userdata-master.tpl", {
    domain = var.hosted_zone,
    token = local.token,
    cluser_name = var.battlefield,
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "master" {
  depends_on           = [aws_launch_configuration.master]
  
  name                 = "${var.battle}-k8s-master"
  max_size             = 2
  min_size             = 1
  desired_capacity     = 1
  force_delete         = true
  launch_configuration = aws_launch_configuration.master.name
  vpc_zone_identifier  = aws_subnet.public.*.id
  load_balancers       = [aws_elb.master-public.id]
  
  tags = [
    {
      key                 = "Name"
      value               = "${var.battle}-k8s-master"
      propagate_at_launch = true
    },
    {
      key                 = "Battle"
      value               = var.battle
      propagate_at_launch = true
    },
    {
      key                 = "Warrior"
      value               = var.warrior
      propagate_at_launch = true
    }
  ]
}

resource "aws_launch_configuration" "worker" {
  depends_on                  = [aws_key_pair.ssh]
  name_prefix                 = "worker-"
  image_id                    = data.aws_ami.ubuntu.id
  instance_type               = var.worker_instance_type
  security_groups             = [
    aws_security_group.egress.id,
    aws_security_group.ingress_internal.id,
    aws_security_group.ingress_k8s.id,
    aws_security_group.ingress_ssh.id
  ]
  key_name                    = var.aws_key_pair_name == null ? aws_key_pair.ssh.0.key_name : var.aws_key_pair_name
  associate_public_ip_address = false
  ebs_optimized               = true
  enable_monitoring           = true
  iam_instance_profile        = aws_iam_instance_profile.etcd_worker_master.id

  user_data = templatefile("${path.module}/userdata-worker.tpl", {
    domain   = var.hosted_zone,
    token = local.token
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker" {
  max_size             = 2
  min_size             = 1
  desired_capacity     = 1
  force_delete         = true
  launch_configuration = aws_launch_configuration.worker.name
  vpc_zone_identifier  = aws_subnet.private.*.id

  tags = [
    {
      key                 = "Name"
      value               = "${var.battle}-k8s-worker"
      propagate_at_launch = true
    },
    {
      key                 = "Battle"
      value               = var.battle
      propagate_at_launch = true
    },
    {
      key                 = "Warrior"
      value               = var.warrior
      propagate_at_launch = true
    }
  ]
}

data "aws_vpc" "main" {
  tags = {
    Name = "${var.battle}-vpc"
  }
}
