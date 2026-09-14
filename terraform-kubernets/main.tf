terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.36"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  backend "s3" {
    bucket         = "f1rsters-tech-challenge-terraform-state"
    key            = "tech-challenge-mecanica/terraform-k8s.tfstate"
    region         = "sa-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Component   = "kubernetes"
    }
  }
}

# ---------------------------------------------------------------------------
# O cluster EKS em si é criado via eksctl (ver pasta eksctl/), NÃO pelo
# Terraform. Este data source apenas lê um cluster já existente para que os
# providers "kubernetes" e "helm" abaixo consigam se autenticar nele.
# Ver README.md para detalhes dessa decisão de arquitetura.
# ---------------------------------------------------------------------------
data "aws_eks_cluster" "observability" {
  count = var.enable_newrelic && var.eks_cluster_name != "" ? 1 : 0
  name  = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "observability" {
  count = var.enable_newrelic && var.eks_cluster_name != "" ? 1 : 0
  name  = var.eks_cluster_name
}

provider "kubernetes" {
  host                   = try(data.aws_eks_cluster.observability[0].endpoint, null)
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.observability[0].certificate_authority[0].data), null)
  token                  = try(data.aws_eks_cluster_auth.observability[0].token, null)
}

provider "helm" {
  kubernetes {
    host                   = try(data.aws_eks_cluster.observability[0].endpoint, null)
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.observability[0].certificate_authority[0].data), null)
    token                  = try(data.aws_eks_cluster_auth.observability[0].token, null)
  }
}
