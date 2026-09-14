# Tech Challenge FIAP - Infraestrutura de Kubernetes e Observabilidade

## Propósito

Este repositório gerencia, via Terraform, a **observabilidade do cluster Kubernetes** (EKS) onde a aplicação da oficina mecânica é executada: instalação do agente New Relic no cluster (via Helm) e provisionamento de alertas e dashboard como código.

### Decisão de arquitetura: o cluster EKS em si NÃO é criado por este Terraform

O cluster é criado de forma imperativa via **eksctl** (arquivos em `eksctl/`), e este repositório apenas se conecta a ele (via `data "aws_eks_cluster"`) para instalar e configurar a observabilidade. Essa decisão foi tomada deliberadamente para reduzir risco/retrabalho no prazo do desafio — migrar a criação do cluster para `aws_eks_cluster`/`aws_eks_node_group` no Terraform é um passo futuro possível, mas está fora do escopo atual.

## Tecnologias utilizadas

| Tecnologia | Uso |
|---|---|
| Terraform >= 1.0 | Infraestrutura como Código (observabilidade) |
| eksctl | Criação/gestão do cluster EKS (fora do Terraform) |
| AWS EKS | Cluster Kubernetes gerenciado |
| Helm (`nri-bundle`) | Agente New Relic instalado no cluster |
| New Relic (Terraform Provider) | Alertas NRQL e dashboard como código |
| GitHub Actions | Pipeline de CI/CD |

## Diagrama de arquitetura

```
┌────────────────────────┐        ┌──────────────────────────────────┐
│   eksctl (imperativo)  │──cria─►│         Cluster EKS               │
│  eksctl-cluster.yaml   │        │      (tech-challenge)             │
│  eksctl-nodegroup.yaml │        │                                    │
└────────────────────────┘        │  ┌──────────────────────────────┐ │
                                   │  │ namespace: newrelic          │ │
        Terraform (este repo)     │  │  helm_release nri-bundle     │ │
        ├─ data.aws_eks_cluster ──┼─►│  (Infra + APM + K8s metrics) │ │
        ├─ provider kubernetes    │  └──────────────────────────────┘ │
        ├─ provider helm          │                                    │
        └─ provider newrelic     │  ┌──────────────────────────────┐ │
              │                    │  │ App (deploy pelo repo         │ │
              ▼                    │  │ mecanica - k8s/)              │ │
     ┌──────────────────┐          │  └──────────────────────────────┘ │
     │   New Relic       │          └──────────────────────────────────┘
     │ alertas + dashboard│
     └──────────────────┘
```

## Recursos provisionados

- `data.aws_eks_cluster` / `data.aws_eks_cluster_auth` — leitura do cluster já existente
- `helm_release.newrelic_eks_bundle` — instala o `nri-bundle` (agente New Relic) no cluster
- `newrelic_alert_policy` + 4x `newrelic_nrql_alert_condition` — alertas de latência, uptime, healthcheck e falhas de processamento de OS
- `newrelic_one_dashboard` — dashboard de observabilidade da aplicação

## Pré-requisitos

- Conta AWS com credenciais configuradas
- [eksctl](https://eksctl.io/) instalado (para criar/gerenciar o cluster)
- Terraform >= 1.0
- Bucket S3 `f1rsters-tech-challenge-terraform-state` e tabela DynamoDB `terraform-locks` já criados (compartilhados entre os 4 repositórios)
- Conta New Relic (opcional — `enable_newrelic = false` por padrão)

## Passos para execução e deploy

### 1. Criar o cluster EKS (uma vez, fora do Terraform)

```bash
eksctl create cluster -f eksctl/eksctl-cluster.yaml
# ou, para ajustar apenas o node group:
eksctl create nodegroup -f eksctl/eksctl-nodegroup.yaml
```

### 2. Provisionar a observabilidade com Terraform

```bash
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars com as credenciais do New Relic (se for usar)

terraform init \
  -backend-config="bucket=f1rsters-tech-challenge-terraform-state" \
  -backend-config="key=tech-challenge-mecanica/terraform-k8s.tfstate" \
  -backend-config="region=sa-east-1" \
  -backend-config="encrypt=true"

terraform plan
terraform apply
```

### Via CI/CD (GitHub Actions)

- **Pull Request / push:** `terraform plan` (comenta o plano no PR)
- **Push em `main` (prod) ou `homologacao` (homolog):** `terraform apply` automático

**Secrets necessários no repositório:**

| Secret | Obrigatório? | Descrição |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Sim | Credencial AWS |
| `AWS_SECRET_ACCESS_KEY` | Sim | Credencial AWS |
| `NEW_RELIC_ACCOUNT_ID` | Não | Habilita observabilidade (junto com `NEW_RELIC_API_KEY`) |
| `NEW_RELIC_API_KEY` | Não | Chave de API do New Relic |
| `NEW_RELIC_LICENSE_KEY` | Não | License key do agente instalado no cluster |
| `EKS_CLUSTER_NAME` | Não | Nome do cluster EKS (padrão: `tech-challenge`) |

> Se os secrets do New Relic não forem configurados, o pipeline roda normalmente com `enable_newrelic = false` — nenhum recurso do New Relic é criado, e o provider usa um valor placeholder para não quebrar o `plan` (ver `newrelic.tf`).

### Destruir a infraestrutura

```bash
terraform destroy
eksctl delete cluster -f eksctl/eksctl-cluster.yaml
```

## Outputs

| Output | Descrição |
|---|---|
| `newrelic_alert_policy_id` | ID da política de alertas criada (ou `null` se `enable_newrelic = false`) |
| `newrelic_bundle_installed` | `true`/`false` se o agente foi instalado no cluster |

## Repositórios relacionados

- [f1rsters-tech-challenge-mecanica](https://github.com/diogocarpio/f1rsters-tech-challenge-mecanica) — aplicação principal (roda no cluster criado aqui)
- [f1rsters-tech-challenge-mecanica-lambda](https://github.com/diogocarpio/f1rsters-tech-challenge-mecanica-lambda) — Lambda de autenticação
- [f1rsters-tech-challenge-mecanica-terraform-bd](https://github.com/diogocarpio/f1rsters-tech-challenge-mecanica-terraform-bd) — banco de dados

## Grupo

**Turma:** F1RSTERS FIAP - Diogo, Alexandra, Rodrigo e Livea
