# ------------------------------------------------------------------------------
# SECURITY GROUPS
# Règles déclarées à part (aws_vpc_security_group_*_rule) : le SG alb et le SG web
# se référencent mutuellement, ce qui créerait un cycle avec des règles en ligne.
# name_prefix + create_before_destroy : un nom fixe empêcherait de créer le
# nouveau SG avant de supprimer l'ancien (deux SG du même nom dans un VPC = refus).
# ------------------------------------------------------------------------------

resource "aws_security_group" "this_alb" {
  name_prefix = "${var.name_prefix}-${var.environment}-alb-"
  description = "Security Group de l'Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-${var.environment}-alb" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "this_web" {
  name_prefix = "${var.name_prefix}-${var.environment}-web-"
  description = "Security Group des instances web"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-${var.environment}-web" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  #checkov:skip=CKV_AWS_260:l'ALB est le point d'entrée public du service, le SG web reste fermé
  security_group_id = aws_security_group.this_alb.id
  description       = "HTTP depuis Internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.this_alb.id
  description                  = "HTTP vers les instances web uniquement"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.this_web.id
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  #checkov:skip=CKV_AWS_260:faux positif, la source est le SG de l'ALB (referenced_security_group_id), pas 0.0.0.0/0
  security_group_id            = aws_security_group.this_web.id
  description                  = "HTTP depuis l'ALB uniquement (pas de port 22)"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.this_alb.id
}

# Sortie limitée au web : dépôts dnf, API SSM / Parameter Store (443).
# Pas de NAT ni de VPC endpoint (choix de coût) : la destination reste Internet.
resource "aws_vpc_security_group_egress_rule" "web_https" {
  security_group_id = aws_security_group.this_web.id
  description       = "HTTPS sortant (dnf, SSM, Parameter Store)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "web_http" {
  security_group_id = aws_security_group.this_web.id
  description       = "HTTP sortant (miroirs de paquets)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# ------------------------------------------------------------------------------
# LAUNCH TEMPLATE & AUTO SCALING GROUP
# ------------------------------------------------------------------------------

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-${var.environment}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  user_data     = var.user_data

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.this_web.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 obligatoire
    http_put_response_hop_limit = 1
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.name_prefix}-${var.environment}-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  target_group_arns   = [aws_lb_target_group.this.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # Remplace les instances quand le Launch Template change (nouveau bootstrap, AMI...).
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-${var.environment}-web"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# ------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# Exceptions acceptées (voir SECURITE.md §5 du dépôt novasphere-infra).
# ------------------------------------------------------------------------------

resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:logs d'accès non activés (coût S3, environnement détruit après chaque session)
  #checkov:skip=CKV_AWS_150:protection contre la suppression incompatible avec la destruction en fin de session
  #checkov:skip=CKV2_AWS_20:pas de HTTPS sans nom de domaine pour valider un certificat ACM
  #checkov:skip=CKV2_AWS_28:WAF hors périmètre et facturé
  name                       = "${var.name_prefix}-${var.environment}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.this_alb.id]
  subnets                    = var.subnet_ids
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "this" {
  #checkov:skip=CKV_AWS_378:trafic ALB vers instances en HTTP à l'intérieur du VPC, pas de certificat
  name     = "${var.name_prefix}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "this" {
  #checkov:skip=CKV_AWS_2:pas de HTTPS sans nom de domaine pour valider un certificat ACM
  #checkov:skip=CKV_AWS_103:TLS non applicable à un listener HTTP
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
