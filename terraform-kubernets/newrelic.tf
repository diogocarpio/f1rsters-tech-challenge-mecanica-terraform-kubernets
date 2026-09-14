provider "newrelic" {
  # O provider exige pelo menos uma credencial não-vazia mesmo quando nenhum
  # recurso newrelic_* será de fato criado (enable_newrelic = false). Por
  # isso usamos um placeholder quando a variável não é fornecida, evitando o
  # erro "must use at least one of: ConfigPersonalAPIKey, ConfigAdminAPIKey,
  # ConfigInsightsInsertKey" durante o `terraform plan`.
  account_id = var.newrelic_account_id != 0 ? var.newrelic_account_id : null
  api_key    = var.newrelic_api_key != "" ? var.newrelic_api_key : "unset-placeholder"
  region     = var.newrelic_region
}

locals {
  nr_entity_name = "${var.project_name}-${var.environment}"
}

resource "helm_release" "newrelic_eks_bundle" {
  count      = var.enable_newrelic && var.eks_cluster_name != "" && var.newrelic_license_key != "" ? 1 : 0
  name       = "newrelic-bundle"
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  namespace  = "newrelic"

  create_namespace = true

  set {
    name  = "global.licenseKey"
    value = var.newrelic_license_key
  }

  set {
    name  = "global.cluster"
    value = var.eks_cluster_name
  }
}

resource "newrelic_alert_policy" "oficina_observability" {
  count               = var.enable_newrelic ? 1 : 0
  name                = "${local.nr_entity_name}-observability-policy"
  incident_preference = "PER_POLICY"
}

resource "newrelic_nrql_alert_condition" "api_latency_p95" {
  count       = var.enable_newrelic ? 1 : 0
  policy_id   = newrelic_alert_policy.oficina_observability[0].id
  type        = "static"
  name        = "${local.nr_entity_name} API Latency p95"
  enabled     = true
  runbook_url = "https://github.com/diogocarpio/f1rsters-tech-challenge-mecanica"

  nrql {
    query = "SELECT percentile(duration, 95) FROM Transaction WHERE appName = '${var.project_name}'"
  }

  critical {
    operator              = "above"
    threshold             = 1.5
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  warning {
    operator              = "above"
    threshold             = 0.8
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "uptime" {
  count     = var.enable_newrelic ? 1 : 0
  policy_id = newrelic_alert_policy.oficina_observability[0].id
  type      = "static"
  name      = "${local.nr_entity_name} Uptime"
  enabled   = true

  nrql {
    query = "SELECT percentage(count(*), WHERE result = 'SUCCESS') FROM SyntheticCheck WHERE monitorName = '${var.project_name}-healthcheck'"
  }

  critical {
    operator              = "below"
    threshold             = 99.5
    threshold_duration    = 3600
    threshold_occurrences = "ALL"
  }

  warning {
    operator              = "below"
    threshold             = 99.9
    threshold_duration    = 3600
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "healthcheck_failures" {
  count     = var.enable_newrelic ? 1 : 0
  policy_id = newrelic_alert_policy.oficina_observability[0].id
  type      = "static"
  name      = "${local.nr_entity_name} Healthcheck failures"
  enabled   = true

  nrql {
    query = "SELECT count(*) FROM Transaction WHERE appName = '${var.project_name}' AND name LIKE '%/actuator/health%' AND httpResponseCode != '200'"
  }

  critical {
    operator              = "above"
    threshold             = 3
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "ordem_servico_processing_failures" {
  count     = var.enable_newrelic ? 1 : 0
  policy_id = newrelic_alert_policy.oficina_observability[0].id
  type      = "static"
  name      = "${local.nr_entity_name} Falhas processamento OS"
  enabled   = true

  nrql {
    query = "SELECT sum(newrelic.timeslice.value) FROM Metric WHERE metricName = 'ordem_servico.processing.failure.total'"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 600
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_one_dashboard" "oficina_observability" {
  count       = var.enable_newrelic ? 1 : 0
  name        = "${local.nr_entity_name}-observability"
  permissions = "public_read_only"

  page {
    name = "Visão Geral"

    widget_billboard {
      title  = "Volume diário de ordens de serviço"
      row    = 1
      column = 1
      width  = 4
      height = 3
      nrql_query {
        query = "SELECT sum(newrelic.timeslice.value) FROM Metric WHERE metricName = 'ordem_servico.created.total' TIMESERIES 1 day"
      }
    }

    widget_line {
      title  = "Tempo médio por status"
      row    = 1
      column = 5
      width  = 4
      height = 3
      nrql_query {
        query = "SELECT average(newrelic.timeslice.value) FROM Metric WHERE metricName = 'ordem_servico.status.lead_time.seconds' FACET status TIMESERIES"
      }
    }

    widget_line {
      title  = "Erros e falhas de integração/processamento"
      row    = 4
      column = 1
      width  = 4
      height = 3
      nrql_query {
        query = "SELECT sum(newrelic.timeslice.value) FROM Metric WHERE metricName = 'ordem_servico.processing.failure.total' FACET reason TIMESERIES"
      }
    }

    widget_area {
      title  = "Saúde e recursos do ambiente"
      row    = 4
      column = 5
      width  = 4
      height = 3
      nrql_query {
        query = "SELECT average(cpuUsedCores), average(memoryUsedBytes/1073741824) FROM K8sContainerSample FACET clusterName TIMESERIES"
      }
    }
  }
}
