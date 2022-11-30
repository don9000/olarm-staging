terraform {
  cloud {
    organization = "olarm"
    workspaces {
      name = "terraform-aws1"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "af-south-1"
}

resource "aws_key_pair" "ssh-key-webfrontend" {
  key_name   = "ssh-key-webfrontend"
  public_key = "to be added"
}

variable "GITHUB_OLARM_ADMIN_DEPLOY_KEY" {
  type = string
  default = ""
}

variable "GITHUB_OLARM_SCHEDULER_DEPLOY_KEY" {
  type = string
  default = ""
}

variable "GITHUB_OLARM_ADMIN_RUNNER_TOKEN" {
  type = string
  default = ""
}

variable "NPM_API_KEY" {
  type = string
  default = ""
}

data "aws_secretsmanager_secret_version" "olarm_config_production_admin_v1" {
  secret_id = "arn:aws:secretsmanager:af-south-1:945519864455:secret:olarm-config-production-admin-v1-iAzEiF"
}

data "aws_secretsmanager_secret_version" "olarm-apns-cert" {
  secret_id = "arn:aws:secretsmanager:af-south-1:945519864455:secret:olarm-apns-cert-dv6Xpj"
}

data "aws_secretsmanager_secret_version" "olarm-apns-key-noenc" {
  secret_id = "arn:aws:secretsmanager:af-south-1:945519864455:secret:olarm-apns-key-noenc-WGQEXq"
}

data "aws_secretsmanager_secret_version" "olarm-hms-config" {
  secret_id = "arn:aws:secretsmanager:af-south-1:945519864455:secret:olarm-hms-config-Cqo5lv"
}

data "aws_secretsmanager_secret_version" "olarm-firebase-config" {
  secret_id = "arn:aws:secretsmanager:af-south-1:945519864455:secret:olarm-firebase-config-52vFdL"
}

resource "aws_instance" "admin-a" {
  ami                       = "ami-030b8d2037063bab3"
  instance_type             = "t3.micro"
  subnet_id                 = "subnet-0beda27df099c4601"
  vpc_security_group_ids    = [aws_security_group.web-frontend-sg.id]
  key_name                  = "ssh-key-webfrontend"
  associate_public_ip_address = "true"
  iam_instance_profile      = "EC2-fetch-S3-buckets"

  root_block_device {
    volume_size = 16
  }

  user_data = templatefile("user-data.sh", {
    OLARM_CONFIG = base64gzip(data.aws_secretsmanager_secret_version.olarm_config_production_admin_v1.secret_string)
    GITHUB_OLARM_ADMIN_DEPLOY_KEY = base64gzip(var.GITHUB_OLARM_ADMIN_DEPLOY_KEY)
    GITHUB_OLARM_SCHEDULER_DEPLOY_KEY = base64gzip(var.GITHUB_OLARM_SCHEDULER_DEPLOY_KEY)
    GITHUB_OLARM_RUNNER_TOKEN = var.GITHUB_OLARM_ADMIN_RUNNER_TOKEN
    NPM_API_KEY = var.NPM_API_KEY
    OLARM_APNS_CERT = base64gzip(data.aws_secretsmanager_secret_version.olarm-apns-cert.secret_string)
    OLARM_APNS_KEY_NOENC = base64gzip(data.aws_secretsmanager_secret_version.olarm-apns-key-noenc.secret_string)
    OLARM_HMS_CONFIG = base64gzip(data.aws_secretsmanager_secret_version.olarm-hms-config.secret_string)
    OLARM_FIREBASE_CONFIG = base64gzip(data.aws_secretsmanager_secret_version.olarm-firebase-config.secret_string)
  })

  tags = {
    Name = "webfrontend-a"
  }
}
resource "aws_route53_record" "webfrontend-a-web-private" {
  zone_id = "Z0120810KSHFR6FKXE3J"
  name    = "login-staging"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.admin-a.private_ip]
}
resource "aws_route53_record" "webfrontend-a-web-public" {
  zone_id = "Z01160843SAN9N22VLXTQ"
  name    = "login-staging"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.webfrontend-a.public_ip]
}
resource "aws_route53_record" "webfrontend-a-api-private" {
  zone_id = "Z0120810KSHFR6FKXE3J"
  name    = "userportal-staging"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.webfrontend-a.private_ip]
}
resource "aws_route53_record" "webfrontend-a-api-public" {
  zone_id = "Z01160843SAN9N22VLXTQ"
  name    = "userportal-staging"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.webfrontend-a.public_ip]
}

resource "aws_route53_record" "webfrontend-a-api-private" {
  zone_id = "Z0120810KSHFR6FKXE3J"
  name    = "commandcentre-staging"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.webfrontend-a.private_ip]
}
resource "aws_route53_record" "webfrontend-a-api-public" {
  zone_id = "Z01160843SAN9N22VLXTQ"
  name    = "commandcentre-staging"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.webfrontend-a.public_ip]
}

resource "aws_security_group" "web-frontend-sg" {
  name = "web-frontend-sg"
  vpc_id = "vpc-0a7379de579213f73"

  tags = {
    Name = "web-frontend-sg"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24"]
    description = "SSH from VDC"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["172.16.1.0/24"]
    description = "ICMP from VDC"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
