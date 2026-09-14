variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "f1rsters-tech-challenge-mecanica"
}

variable "environment" {
  description = "Environment name (dev, homolog, prod) - usado apenas para tags"
  type        = string
  default     = "dev"
}

variable "eks_cluster_name" {
  description = "Nome do cluster EKS existente (criado via eksctl, ver pasta eksctl/), usado para a integracao do New Relic"
  type        = string
  default     = ""
}

variable "enable_newrelic" {
  description = "Habilita o provisionamento dos recursos de observabilidade New Relic (alertas, dashboard e agente no cluster)"
  type        = bool
  default     = false
}

variable "newrelic_account_id" {
  description = "New Relic account ID"
  type        = number
  default     = 0
}

variable "newrelic_api_key" {
  description = "New Relic user API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "newrelic_region" {
  description = "New Relic region (US ou EU)"
  type        = string
  default     = "US"
}

variable "newrelic_license_key" {
  description = "New Relic license key (usada pelo agente instalado no cluster via Helm)"
  type        = string
  sensitive   = true
  default     = ""
}
