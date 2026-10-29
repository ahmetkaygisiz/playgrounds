KUBECONFIG := $(CURDIR)/kubeconfig
export KUBECONFIG

# WSL'de /mnt/c altı "world writable" sayılır ve Ansible cwd'deki ansible.cfg'yi
# yok sayar (inventory yüklenmez -> "no hosts matched"). Config'i açıkça veriyoruz.
ANSIBLE_CONFIG := $(CURDIR)/ansible/ansible.cfg
export ANSIBLE_CONFIG

.PHONY: help deps ping sudo network site k3s floci bootstrap aws nodes apps reset

help: ## Komutları listele
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

deps: ## Ansible collection'larını kur
	cd ansible && ansible-galaxy collection install -r requirements.yml -p collections

ping: ## Pi'lere SSH erişimini test et (sabit IP'ler)
	cd ansible && ansible all -m ping

sudo: ## Şifresiz sudo tanımla (sudo şifresini bir kez sorar)
	cd ansible && ANSIBLE_BECOME_ASK_PASS=True ansible-playbook sudo.yml

network: ## Pi'lere sabit IP ata (nmcli)
	cd ansible && ansible-playbook network.yml

site: ## Boş Pi'leri baştan sona kur (OS + k3s + Floci)
	cd ansible && ansible-playbook site.yml

k3s: ## Sadece k3s adımları
	cd ansible && ansible-playbook site.yml --tags k3s

floci: ## Sadece Docker + Floci
	cd ansible && ansible-playbook site.yml --tags floci

bootstrap: ## Secret'lar + ArgoCD + root app (Terraform)
	cd terraform/bootstrap && terraform init -upgrade && terraform apply

aws: ## Floci üzerinde AWS kaynakları (Terraform)
	cd terraform/floci && terraform init -upgrade && terraform apply

nodes: ## Node'ları ve rollerini göster
	kubectl get nodes -L homelab/role -o wide

apps: ## ArgoCD uygulamalarının durumu
	kubectl -n argocd get applications

reset: ## DİKKAT: k3s'i tamamen kaldırır
	cd ansible && ansible-playbook reset.yml -e confirm=yes
