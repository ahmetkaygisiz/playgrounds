# Homelab: Raspberry Pi k3s + GitOps + Floci

Boş Raspberry Pi'lerden, tek komut dizisiyle çalışan bir DevOps/AI lab'ı kurar.

| Katman | Araç | Ne yapar |
|---|---|---|
| İşletim sistemi + cluster | **Ansible** | Pi ayarları, k3s kurulumu, Docker + Floci |
| Cluster bootstrap | **Terraform** | Secret'lar, ArgoCD, root application |
| Uygulamalar | **ArgoCD (GitOps)** | Prometheus, Grafana, Loki, Alloy, n8n + PostgreSQL |
| AWS pratiği | **Terraform + Floci** | S3, SNS→SQS (DLQ), DynamoDB — ücretsiz, yerel |

## Topoloji

| Cihaz | Sabit IP | k3s rolü | `homelab/role` | Çalışanlar |
|---|---|---|---|---|
| Pi 5 4GB (`pilabs01`) | 192.168.50.250 | server | `control` | k3s control plane, ArgoCD, Traefik |
| Pi 5 8GB (`pilabs02`) | 192.168.50.251 | agent | `monitoring` | Prometheus, Grafana, Alertmanager, Loki |
| Pi 5 8GB (`pilabs03`) | 192.168.50.252 | agent | `apps` | n8n, PostgreSQL, **Floci (Docker, k3s dışında)** |
| PC (Windows + WSL2) | — | — | — | Ansible/Terraform çalıştırır, Ollama (GPU) |

Varsayılan kurulum **SD kart dostudur**: tek server (SQLite), journald RAM'de, swap kapalı,
kısa metrik/log saklama süreleri. SSD'ye geçince HA'yı açabilirsiniz (aşağıda).

## Dizin yapısı

```
homelab/
├── Makefile                  # kısayollar: make site, make bootstrap ...
├── ansible/
│   ├── inventory/hosts.yml   # IP'ler ve roller  <-- DÜZENLEYİN
│   ├── inventory/group_vars/all.yml
│   ├── site.yml              # tüm kurulum
│   ├── reset.yml             # k3s'i kaldırır
│   └── roles/ common | k3s | docker | floci
├── terraform/
│   ├── bootstrap/            # secret'lar + ArgoCD + root app
│   └── floci/                # Floci üzerinde AWS kaynakları
└── k8s/
    ├── root/                 # app-of-apps (her şablon bir ArgoCD Application)
    └── workloads/n8n/        # n8n + PostgreSQL chart'ı
```

## 0. Hazırlık

**Pi'ler:** Raspberry Pi Imager ile **Raspberry Pi OS Lite (64-bit)** yazın. Imager ayarlarında:
hostname (`pilabs01`, `pilabs02`, `pilabs03`), kullanıcı `pi`, **SSH açık + public key**.
Pi'ler ilk açılışta DHCP'den IP alır; sabit IP'yi Ansible atar (aşağıda).

**PC (WSL2 Ubuntu):**
```bash
sudo apt install -y python3-pip make
pip install --user ansible-core
# Terraform: https://developer.hashicorp.com/terraform/install
# kubectl:   https://kubernetes.io/docs/tasks/tools/
ssh-copy-id padawan@<PI_DHCP_IP>   # her Pi için (Imager'da key verdiyseniz gerekmez)
```

**Git:** Bu klasörü GitHub'a push edin. ArgoCD uygulamaları oradan okur.

## 1. Sabit IP'ler (Ansible + nmcli)

| Hostname | Sabit IP |
|---|---|
| pilabs01 | 192.168.50.250 |
| pilabs02 | 192.168.50.251 |
| pilabs03 | 192.168.50.252 |

Ağ ayarları `ansible/inventory/group_vars/all.yml` içinde: `lab_gateway: 192.168.50.1`,
`lab_dns`, `lab_net_prefix: 24`.

1. Her Pi'nin şu anki DHCP IP'sini router'dan bulun ve `hosts.yml`'de ilgili `dhcp_ip` satırını açın.
2. `make deps && make sudo && make network`
   `make sudo` `padawan` için şifresiz sudo tanımlar (sudo şifresini bir kez sorar; Pi'lerde
   zaten şifresizse Enter'a basmanız yeterli). Ardından Ansible DHCP IP'ye bağlanır, NetworkManager bağlantısını (`nmcli con mod ... ipv4.method manual`)
   sabit IP'ye çevirir, bağlantıyı yeniler ve yeni IP'den bağlanıp doğrular.
3. Başarılı olunca `dhcp_ip` satırlarını tekrar yorum yapın. Sonraki çalıştırmalarda bir şey değişmez.

> **Önemli:** 192.168.50.250–252 router'ın DHCP havuzunun **dışında** olmalı, yoksa router aynı
> IP'yi başka bir cihaza verebilir. Havuz bu adresleri kapsıyorsa ya havuzu daraltın
> (ör. .100–.200) ya da bu üç IP için router'da DHCP reservation da tanımlayın.
>
> Pi'ler Wi-Fi ile bağlıysa (Imager'daki `preconfigured` bağlantısı) da çalışır, ancak cluster
> için Ethernet kablosu çok daha kararlıdır.

## 2. Pi'leri kur (Ansible)

```bash
make ping     # 3 Pi de sabit IP'lerinden "pong" demeli
make site     # (network) + OS ayarları + k3s + Docker + Floci (ilk seferde Pi'ler 1 kez reboot olur)
make nodes    # 3 node Ready, roller görünür olmalı
```

k3s token'ı otomatik üretilir ve `ansible/credentials/` altında saklanır (Git'e girmez).
Kubeconfig repo köküne `kubeconfig` olarak yazılır; Makefile bunu otomatik kullanır.

## 3. GitOps'u başlat (Terraform)

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # git_repo_url'i yazın
cd ../.. && make bootstrap
make apps     # birkaç dakika içinde hepsi Synced/Healthy olmalı
```

Şifreler:
```bash
cd terraform/bootstrap
terraform output -raw grafana_admin_password
eval "$(terraform output -raw argocd_admin_password_command)"
```

Bundan sonra **kümeye elle `kubectl apply` yapmayın**: `k8s/` altında değişiklik yapıp push edin,
ArgoCD uygular. Bir uygulamayı kapatmak için `k8s/root/values.yaml` → `apps:` altında `false` yapın.

## 4. Alan adları

Traefik her node'un 80 portunda dinler. PC'nizde (Windows: `C:\Windows\System32\drivers\etc\hosts`)
veya router/AdGuard DNS'inde:

```
192.168.50.250  argocd.pilabs.lan grafana.pilabs.lan prometheus.pilabs.lan n8n.pilabs.lan
```

> `.local` yerine `home.arpa` kullanıyoruz: `.local` mDNS ile çakışır, `home.arpa` ev ağları
> için ayrılmış resmi alan adıdır (RFC 8375).

## 5. Floci + Terraform ile AWS pratiği

```bash
make aws
aws --endpoint-url http://192.168.50.252:4566 s3 ls
aws --endpoint-url http://192.168.50.252:4566 sns publish \
  --topic-arn arn:aws:sns:eu-central-1:000000000000:homelab-events --message "merhaba"
aws --endpoint-url http://192.168.50.252:4566 sqs receive-message \
  --queue-url http://192.168.50.252:4566/000000000000/homelab-events
```

(`aws configure` ile access/secret key olarak `test`/`test` girin.)

**ARM64 notu:** Ansible, Floci image'ında arm64 olup olmadığını kontrol eder. Yoksa kurulum
uyarıyla durur; bu durumda Floci'yi PC'de WSL2 + Docker ile `ansible/roles/floci/templates`
içindeki compose dosyasıyla çalıştırın, `hosts.yml`'deki `floci` grubunu boşaltın ve
`terraform/floci` içindeki `floci_endpoint`'i PC'nin IP'sine çevirin.

## 6. n8n + yerel LLM (Ollama, PC'deki GPU)

Windows'ta Ollama'nın ağdan erişilebilir olması için `OLLAMA_HOST=0.0.0.0` ortam değişkenini
tanımlayıp Ollama'yı yeniden başlatın ve Windows Güvenlik Duvarı'nda 11434 portuna izin verin.
n8n'de **Ollama** credential'ı oluştururken Base URL: `http://<PC_IP>:11434`.

## HA'ya geçiş (SSD'ye geçtikten sonra)

1. `group_vars/all.yml` → `k3s_ha: true`
2. `hosts.yml` → `pilabs02` ve `pilabs03`'yi `k3s_server` grubuna taşıyın
3. Cluster'ı sıfırdan kurun: `make reset && make site && make bootstrap`

Gömülü etcd + 12 saatte bir otomatik snapshot ile gelir.

## Sürüm sabitleme

Helm chart'ları ilk kurulumda en güncel sürümle gelir (`"*"`). Çalışan bir kurulumdan sonra:
```bash
kubectl -n argocd get applications -o custom-columns=APP:.metadata.name,REV:.status.sync.revision
```
çıktısındaki sürümleri `k8s/root/values.yaml` → `chartVersions` altına, ArgoCD sürümünü de
`argocd_chart_version` değişkenine yazın. Böylece lab tekrar üretilebilir olur.

## Sorun giderme

| Belirti | Kontrol |
|---|---|
| Node `NotReady` | `ssh pi@IP 'sudo journalctl -u k3s -n 100'` (agent'ta `k3s-agent`) |
| Pod `Pending` | `kubectl describe pod ...` — çoğunlukla nodeSelector/disk |
| ArgoCD `OutOfSync` | `kubectl -n argocd describe application <ad>` |
| Prometheus yavaş/çöküyor | SD kart sınırı: `storage.prometheusRetention`'ı düşürün veya SSD'ye geçin |

## Sonraki adımlar

- **Sealed Secrets / External Secrets:** secret'ları da GitOps'a almak
- **cert-manager:** iç CA ile HTTPS
- **Longhorn:** SSD'lerden sonra replike depolama (`open-iscsi` zaten kurulu)
- **GPU node:** PC'ye Linux kurup `k3s_agent` grubuna ekleyin, NVIDIA GPU Operator ile Ollama'yı cluster'a taşıyın
