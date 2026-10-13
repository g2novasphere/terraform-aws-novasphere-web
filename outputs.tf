output "alb_dns_name" {
  description = "Le nom DNS public de l'Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "L'ARN du Target Group (utile si on doit y attacher d'autres ressources)"
  value       = aws_lb_target_group.this.arn
}

output "asg_name" {
  description = "Le nom de l'Auto Scaling Group"
  value       = aws_autoscaling_group.this.name
}