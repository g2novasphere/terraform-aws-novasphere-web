variable "name_prefix" {
  type        = string
  description = "Préfixe pour le nommage des ressources"
}

variable "environment" {
  type        = string
  description = "Environnement (dev ou prod)"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev' ou 'prod'."
  }
}

variable "vpc_id" {
  type        = string
  description = "ID du VPC où déployer les ressources"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Liste des IDs des sous-réseaux pour l'ALB et l'ASG"
}

variable "instance_type" {
  type        = string
  description = "Type d'instance EC2"
}

variable "ami_id" {
  type        = string
  description = "ID de l'AMI Amazon Linux 2023"
}

variable "instance_profile_name" {
  type        = string
  description = "Nom du profil d'instance IAM pour les EC2"
}

variable "user_data" {
  type        = string
  description = "Script de démarrage (bootstrap) encodé en base64"
}

variable "min_size" {
  type        = number
  description = "Taille minimale de l'Auto Scaling Group"
  validation {
    condition     = var.min_size >= 2
    error_message = "L'Auto Scaling Group doit avoir une taille minimale de 2 pour la haute disponibilité."
  }
}

variable "max_size" {
  type        = number
  description = "Taille maximale de l'Auto Scaling Group"
}