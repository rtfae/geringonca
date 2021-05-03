variable "enable" {
  type    =  "string"
  default = false
}

variable "aws_vpc_id" {
  type    =  "string"
  default = false
}

variable "battle" {
  description = "Battle name will be placed as tags"
  type        = string
  default     = "rtfa.life"
}

variable "warrior" {
  description = "Warrior name will be remember in tags"
  type        = string
  default     = "Rodrigo Toledo"
}

data "aws_instances" "lb_instances" {
  instance_tags = {
    Name = "${var.battle}-k8s-master*"
  }
  instance_state_names = ["running", "stopped"]
}

variable "lb_listeners" {
  default = [
    {
      protocol      = "TCP"
      target_port   = "80"
      health_port   = "1936"
    },
    {
      protocol      = "TCP"
      target_port   = "443"
      health_port   = "1936"
    },
    {
      protocol      = "TCP"
      target_port   = "6443"
      health_port   = "1936"
    }
  ]
}

# Load Balancer
resource "aws_lb" "main" {
  count = "${var.enable == "true" ? 1 : 0}"
  
  name_prefix         = "main-"
  internal            = false
  load_balancer_type  = "application"
  subnets             = aws_subnet.public.*.id
  security_groups     = [aws_security_group.master-public-lb.id]

  tags = {
    Name    = "${var.battle}-main-alb"
    Battle = var.battle
    Warrior   = var.warrior
  }
}

resource "aws_route53_zone" "main" {
  name = var.hosted_zone

  tags = {
    Name    = "${var.battle}-route-53"
    Battle = var.battle
    Warrior   = var.warrior
  }
}
resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.hosted_zone
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "kube" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "kube.${var.hosted_zone}"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_lb.main.dns_name]
}

resource "aws_acm_certificate" "main_crt" {
  domain_name       = var.hosted_zone
  subject_alternative_names = ["*.${var.hosted_zone}"]
  validation_method = "DNS"

  tags = {
    Name    = "${var.battle}-main-crt"
    Battle = var.battle
    Warrior   = var.warrior
  }

  lifecycle {
    create_before_destroy = true
  }  
}

resource "aws_route53_record" "main_crt_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main_crt.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}
  
resource "aws_lb_target_group" "lb_main_tg_http" {
  deregistration_delay = 300
  name     = "lb-tgr-http"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.aws_vpc_id
}

resource "aws_lb_target_group" "lb_main_tg_https" {
  deregistration_delay = 300
  name     = "lb-tgr-https"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.aws_vpc_id
}

resource "aws_lb_target_group" "lb_main_tg_kube" {
  deregistration_delay = 300
  name     = "lb-tgr-http-kube"
  port     = 6443
  protocol = "HTTPS"
  vpc_id   = var.aws_vpc_id
}


resource "aws_lb_target_group_attachment" "tgr_attachment_http" {
  for_each = {
    for pair in setproduct(keys(aws_lb_target_group.lb_main_tg_http), data.aws_instances.lb_instances.ids) :
    "${pair[0]}:${pair[1]}" => {
      target_group = aws_lb_target_group.lb_main_tg_http[pair[0]]
      instance_id  = pair[1]
    }
  }
  target_group_arn = aws_lb_target_group.lb_main_tg_http.arn
  target_id        = each.value.instance_id
  port             = aws_lb_target_group.lb_main_tg_http.port
}

resource "aws_lb_target_group_attachment" "tgr_attachment_https" {
  for_each = {
    for pair in setproduct(keys(aws_lb_target_group.lb_main_tg_https), data.aws_instances.lb_instances.ids) :
    "${pair[0]}:${pair[1]}" => {
      target_group = aws_lb_target_group.lb_main_tg_https[pair[0]]
      instance_id  = pair[1]
    }
  }
  target_group_arn = aws_lb_target_group.lb_main_tg_https.arn
  target_id        = each.value.instance_id
  port             = aws_lb_target_group.lb_main_tg_https.port
}

resource "aws_lb_target_group_attachment" "tgr_attachment_kube" {
  for_each = {
    for pair in setproduct(keys(aws_lb_target_group.lb_main_tg_kube), data.aws_instances.lb_instances.ids) :
    "${pair[0]}:${pair[1]}" => {
      target_group = aws_lb_target_group.lb_main_tg_kube[pair[0]]
      instance_id  = pair[1]
    }
  }
  target_group_arn = aws_lb_target_group.lb_main_tg_kube.arn
  target_id        = each.value.instance_id
  port             = aws_lb_target_group.lb_main_tg_kube.port
}


resource "aws_lb_listener" "main-listener-http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  depends_on        = [aws_lb_target_group.lb_main_tg_http]
  default_action {
    target_group_arn = aws_lb_target_group.lb_main_tg_http.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "main-listener-https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  depends_on        = [aws_lb_target_group.lb_main_tg_https]
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.main_crt.arn
  default_action {
    target_group_arn = aws_lb_target_group.lb_main_tg_https.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "main-listener-https-kube" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  depends_on        = [aws_lb_target_group.lb_main_tg_kube]
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.main_crt.arn
  default_action {
    target_group_arn = aws_lb_target_group.lb_main_tg_kube.arn
    type             = "forward"
  }
}