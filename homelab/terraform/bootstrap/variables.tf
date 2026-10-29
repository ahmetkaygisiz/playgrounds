variable "kubeconfig_path" {
  description = "Ansible'ın oluşturduğu kubeconfig"
  type        = string
  default     = "../../kubeconfig"
}

variable "git_repo_url" {
  description = "Bu reponun Git adresi (ArgoCD buradan okur), örn. https://github.com/kullanici/homelab.git"
  type        = string
}

variable "git_revision" {
  description = "ArgoCD'nin izleyeceği branch"
  type        = string
  default     = "main"
}

variable "git_repo_token" {
  description = "Repo private ise GitHub fine-grained token (salt okunur). Public repo için boş bırakın."
  type        = string
  default     = ""
  sensitive   = true
}

variable "git_repo_username" {
  description = "Private repo için kullanıcı adı"
  type        = string
  default     = "git"
}

variable "lab_domain" {
  description = "Ingress alan adı (Ansible'daki lab_domain ile aynı)"
  type        = string
  default     = "pilabs"
}

variable "timezone" {
  type    = string
  default = "Europe/Istanbul"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart sürümü. Boş = en güncel. İlk kurulumdan sonra sabitlemeniz önerilir."
  type        = string
  default     = null
}
