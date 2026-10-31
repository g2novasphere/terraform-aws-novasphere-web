# Module Terraform AWS - NovaSphere Web

Ce module déploie l'infrastructure web de l'application NovaSphere (Application Load Balancer, Auto Scaling Group, et instances EC2 basées sur Amazon Linux 2023).

## 🚀 Utilisation

Pour utiliser ce module dans votre infrastructure, ajoutez le bloc suivant dans votre fichier `.tf` principal (en remplaçant le `ref=` par le tag de la version souhaitée) :

```hcl
module "web" {
  source = "git::[https://github.com/g2novasphere/terraform-aws-novasphere-web.git?ref=v1.5.0](https://github.com/g2novasphere/terraform-aws-novasphere-web.git?ref=v1.5.0)"

  name_prefix           = "novasphere"
  environment           = "dev" # ou "prod"
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnets
  instance_type         = "t2.micro"
  ami_id                = data.aws_ami.al2023.id
  instance_profile_name = aws_iam_instance_profile.instance.name
  user_data             = base64encode(file("${path.module}/bootstrap.sh"))
  
  min_size              = 1
  max_size              = 2
}

## ⚙️ Variables d'entrée (Inputs)

| Nom | Type | Description | Requis |
|------|------|-------------|:------:|
| `name_prefix` | `string` | Préfixe utilisé pour nommer les ressources | Oui |
| `environment` | `string` | L'environnement de déploiement (ex: dev, prod) | Oui |
| `vpc_id` | `string` | L'ID du VPC dans lequel déployer | Oui |
| `subnet_ids` | `list(string)` | Liste des IDs des sous-réseaux (publics pour l'ALB) | Oui |
| `instance_type` | `string` | Le type d'instance EC2 (ex: t2.micro) | Oui |
| `ami_id` | `string` | L'ID de l'AMI Amazon Linux 2023 à utiliser | Oui |
| `instance_profile_name` | `string` | Le nom du profil d'instance IAM à attacher aux EC2 | Oui |
| `user_data` | `string` | Le script de démarrage (doit être encodé en base64) | Oui |
| `min_size` | `number` | Nombre minimum d'instances dans l'ASG | Oui |
| `max_size` | `number` | Nombre maximum d'instances dans l'ASG | Oui |

## 🛡️ Sécurité & Checkov

Ce module a été conçu pour l'environnement académique NovaSphere. Certaines règles de sécurité strictes de production (`CKV_AWS_260`, `CKV_AWS_382`, etc.) ont été délibérément ignorées via des annotations `#checkov:skip` pour permettre l'accès HTTP public (Port 80) sur le Load Balancer et l'accès sortant total pour l'installation des paquets.
