\# Module Terraform AWS - NovaSphere Web



Ce module déploie l'infrastructure web de l'application NovaSphere (Application Load Balancer, Auto Scaling Group, et instances EC2 basées sur Amazon Linux 2023).



\## 🚀 Utilisation



Pour utiliser ce module dans votre infrastructure, ajoutez le bloc suivant dans votre fichier `.tf` principal (en remplaçant le `ref=` par le tag de la version souhaitée) :



```hcl

module "web" {

&#x20; source = "git::\[https://github.com/g2novasphere/terraform-aws-novasphere-web.git?ref=v1.5.0](https://github.com/g2novasphere/terraform-aws-novasphere-web.git?ref=v1.5.0)"



&#x20; name\_prefix           = "novasphere"

&#x20; environment           = "dev" # ou "prod"

&#x20; vpc\_id                = module.vpc.vpc\_id

&#x20; subnet\_ids            = module.vpc.public\_subnets

&#x20; instance\_type         = "t2.micro"

&#x20; ami\_id                = data.aws\_ami.al2023.id

&#x20; instance\_profile\_name = aws\_iam\_instance\_profile.instance.name

&#x20; user\_data             = base64encode(file("${path.module}/bootstrap.sh"))

&#x20; 

&#x20; min\_size              = 1

&#x20; max\_size              = 2

}



\## ⚙️ Variables d'entrée (Inputs)



| Nom | Type | Description | Requis |

|------|------|-------------|:------:|

| `name\_prefix` | `string` | Préfixe utilisé pour nommer les ressources | Oui |

| `environment` | `string` | L'environnement de déploiement (ex: dev, prod) | Oui |

| `vpc\_id` | `string` | L'ID du VPC dans lequel déployer | Oui |

| `subnet\_ids` | `list(string)` | Liste des IDs des sous-réseaux (publics pour l'ALB) | Oui |

| `instance\_type` | `string` | Le type d'instance EC2 (ex: t2.micro) | Oui |

| `ami\_id` | `string` | L'ID de l'AMI Amazon Linux 2023 à utiliser | Oui |

| `instance\_profile\_name` | `string` | Le nom du profil d'instance IAM à attacher aux EC2 | Oui |

| `user\_data` | `string` | Le script de démarrage (doit être encodé en base64) | Oui |

| `min\_size` | `number` | Nombre minimum d'instances dans l'ASG | Oui |

| `max\_size` | `number` | Nombre maximum d'instances dans l'ASG | Oui |



\## 🛡️ Sécurité \& Checkov



Ce module a été conçu pour l'environnement académique NovaSphere. Certaines règles de sécurité strictes de production (`CKV\_AWS\_260`, `CKV\_AWS\_382`, etc.) ont été délibérément ignorées via des annotations `#checkov:skip` pour permettre l'accès HTTP public (Port 80) sur le Load Balancer et l'accès sortant total pour l'installation des paquets.

