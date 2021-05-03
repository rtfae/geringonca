# IAM Roles for EC2 Instance Profiles
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

## etcd & Kubernetes instances
data "aws_iam_policy_document" "etcd_worker_master" {
  statement {
    sid = "autoscaling"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeTags",
      "elasticloadbalancing:DescribeLoadBalancers"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "etcd_worker_master" {
  name_prefix = "etcd-worker-master-"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name    = "${var.battle}-etcd-worker-master"
    Battle  = var.battle
    Warrior = var.warrior
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy" "etcd_worker_master" {
  name_prefix = "etcd-worker-master-"
  role        = aws_iam_role.etcd_worker_master.id
  policy      = data.aws_iam_policy_document.etcd_worker_master.json
}

resource "aws_iam_instance_profile" "etcd_worker_master" {
  name_prefix = "etcd-worker-master-"
  role        = aws_iam_role.etcd_worker_master.name
}