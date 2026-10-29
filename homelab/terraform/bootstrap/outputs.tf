output "urls" {
  value = {
    argocd     = "http://argocd.${var.lab_domain}"
    grafana    = "http://grafana.${var.lab_domain}"
    prometheus = "http://prometheus.${var.lab_domain}"
    n8n        = "http://n8n.${var.lab_domain}"
  }
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}

output "argocd_admin_password_command" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
