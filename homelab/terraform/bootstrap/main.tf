# Bu katman cluster'ı "GitOps'a hazır" hale getirir:
#   1) Git'e konmaması gereken secret'lar (rastgele üretilir)
#   2) ArgoCD
#   3) Root Application (app-of-apps) -> k8s/root
# Geri kalan her şeyi ArgoCD Git'ten yönetir.

# ---------- Namespace'ler ----------
resource "kubernetes_namespace_v1" "this" {
  for_each = toset(["monitoring", "n8n"])
  metadata {
    name = each.key
  }
  lifecycle {
    # ArgoCD sonradan label/annotation ekleyebilir
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

# ---------- Secret'lar ----------
resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "random_password" "n8n_db" {
  length  = 32
  special = false
}

resource "random_password" "n8n_encryption_key" {
  length  = 48
  special = false
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace_v1.this["monitoring"].metadata[0].name
  }
  data = {
    "admin-user"     = "admin"
    "admin-password" = random_password.grafana_admin.result
  }
}

resource "kubernetes_secret_v1" "n8n" {
  metadata {
    name      = "n8n-secrets"
    namespace = kubernetes_namespace_v1.this["n8n"].metadata[0].name
  }
  data = {
    "postgres-password" = random_password.n8n_db.result
    # n8n credential'larını bu anahtarla şifreler; kaybederseniz kayıtlı credential'lar açılamaz
    "encryption-key" = random_password.n8n_encryption_key.result
  }
}

# ---------- ArgoCD ----------
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  timeout          = 900 # Pi'de image çekmek uzun sürebilir

  values = [yamlencode({
    global = {
      domain       = "argocd.${var.lab_domain}"
      nodeSelector = { "homelab/role" = "control" }
    }
    configs = {
      params = {
        "server.insecure" = true # TLS'i Traefik/ingress tarafında bırakıyoruz
      }
      cm = {
        "timeout.reconciliation" = "180s"
      }
    }
    server = {
      ingress = {
        enabled          = true
        ingressClassName = "traefik"
      }
    }
    dex = { enabled = false }
    # Pi için hafif kaynak istekleri
    controller = { resources = { requests = { cpu = "100m", memory = "256Mi" } } }
    repoServer = { resources = { requests = { cpu = "50m", memory = "128Mi" } } }
  })]
}

# Private repo ise ArgoCD'ye erişim bilgisi
resource "kubernetes_secret_v1" "argocd_repo" {
  count = var.git_repo_token == "" ? 0 : 1

  metadata {
    name      = "homelab-repo"
    namespace = helm_release.argocd.namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  data = {
    type     = "git"
    url      = var.git_repo_url
    username = var.git_repo_username
    password = var.git_repo_token
  }
}

# ---------- Root Application (app-of-apps) ----------
resource "helm_release" "root_app" {
  name      = "homelab-root"
  namespace = helm_release.argocd.namespace
  chart     = "${path.module}/charts/root-app"

  values = [yamlencode({
    repoURL        = var.git_repo_url
    repoPath       = trim(var.git_repo_path, "/")
    targetRevision = var.git_revision
    domain         = var.lab_domain
    timezone       = var.timezone
  })]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.argocd_repo,
    kubernetes_secret_v1.grafana_admin,
    kubernetes_secret_v1.n8n,
  ]
}
