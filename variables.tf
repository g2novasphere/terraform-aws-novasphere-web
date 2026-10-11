variable "environment" {
  type        = string
  description = "L'environnement de déploiement (dev ou prod)"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "L'environnement doit obligatoirement être 'dev' ou 'prod'."
  }
}