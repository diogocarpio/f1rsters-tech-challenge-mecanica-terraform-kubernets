output "newrelic_alert_policy_id" {
  description = "ID da politica de alertas do New Relic"
  value       = var.enable_newrelic ? newrelic_alert_policy.oficina_observability[0].id : null
}

output "newrelic_bundle_installed" {
  description = "Indica se o agente New Relic (nri-bundle) foi instalado no cluster via Helm"
  value       = length(helm_release.newrelic_eks_bundle) > 0
}
