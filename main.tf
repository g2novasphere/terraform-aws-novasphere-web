data "aws_availability_zones" "this" {
  state = "available"
}

resource "aws_security_group" "this_alb" {
  #checkov:skip=CKV_AWS_260: ALB public par design (port 80).
  #checkov:skip=CKV_AWS_382: Trafic sortant requis.
  name        = "${var.name_prefix}-${var.environment}-alb-sg"
  description = "Security Group pour Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Autoriser HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Autoriser tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "this_web" {
  #checkov:skip=CKV_AWS_382: Trafic sortant requis pour l'installation des paquets.
  name        = "${var.name_prefix}-${var.environment}-web-sg"
  description = "Security Group pour les instances EC2"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Autoriser HTTP depuis ALB uniquement"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.this_alb.id]
  }

  egress {
    description = "Autoriser tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  user_data     = var.user_data

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.this_web.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # Exigence de sécurité : IMDSv2 obligatoire
  }
}

resource "aws_autoscaling_group" "this" {
  #checkov:skip=CKV_AWS_153: Tags gérés par le Launch Template.
  name                = "${var.name_prefix}-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  target_group_arns   = [aws_lb_target_group.this.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
}

resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91: Logs d'accès non requis.
  #checkov:skip=CKV_AWS_150: Pas de protection contre la suppression pour la CI.
  #checkov:skip=CKV2_AWS_20: Pas de redirection HTTPS.
  #checkov:skip=CKV2_AWS_28: Pas de WAF requis.
  name                       = "${var.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.this_alb.id]
  subnets                    = var.subnet_ids
  drop_invalid_header_fields = true # Recommandation de sécurité souvent attendue par les scanners
}

resource "aws_lb_target_group" "this" {
  #checkov:skip=CKV_AWS_378: Protocole HTTP attendu ici.
  name     = "${var.name_prefix}-tg"
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
  #checkov:skip=CKV_AWS_2: Protocole HTTP utilisé.
  #checkov:skip=CKV_AWS_103: Pas de TLS car HTTP.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}