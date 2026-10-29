# Ev dışından erişim: VS Code Remote Tunnel

Lab'a evin dışından, **hiçbir şey kurmadan, sadece tarayıcıyla** erişmek için. Şirket
bilgisayarında da çalışır: VPN ile çakışmaz, kurulum gerektirmez.

```
Tarayıcı (vscode.dev)  ──HTTPS──▶  Microsoft dev tunnel  ◀──giden bağlantı──  pilabs03
                                                                              │ kubectl, aws, ssh
                                                                              ▼
                                                                    pilabs01 / pilabs02 / Floci
```

- **pilabs03** VS Code sunucusunu çalıştırır. Editör ve terminal ondadır; `kubectl`, `aws` (Floci),
  `ssh` komutları ev ağının içinden çalışır.
- Grafana, ArgoCD gibi arayüzler `kubectl port-forward` ile açılır, VS Code bunları tarayıcınıza taşır.
- Router'da port açılmaz, Pi'ler internetten görünmez. Tünele sadece **sizin GitHub hesabınız** girebilir.
- **Yedek:** pilabs01'de Raspberry Pi Connect çalışır; tünel bozulursa tarayıcıdan terminal açarsınız.

Hangi Pi'lerin kullanılacağı `ansible/inventory/hosts.yml` içindeki `vscode_tunnel` ve
`pi_connect` gruplarında tanımlı.

## Kurulum

Önkoşul: `make site` çalışmış olmalı (repo kökünde `kubeconfig` dosyası oluşur).

### 1. Ansible'ı çalıştırın

```bash
make remote
```

pilabs03'e şunları kurar:

| | |
|---|---|
| VS Code CLI | `/usr/local/bin/code` |
| `kubectl` + kubeconfig | `~/.kube/config` (sunucu: 192.168.50.250) |
| `aws` CLI | Floci için |
| Repo | `~/playgrounds` (varsa dokunulmaz) |
| SSH anahtarı | diğer Pi'lere eklenir: `ssh pilabs01` şifresiz çalışır |
| `lab-ui` + kısayollar | aşağıda |

İlk çalıştırmada GitHub girişi olmadığı için tünel adımında durur ve talimat yazar.

### 2. GitHub girişi (bir kez)

```bash
ssh padawan@192.168.50.252
code tunnel user login --provider github
```

Ekrandaki kodu kendi bilgisayarınızda <https://github.com/login/device> adresine girin.

> **GitHub hesabınızda 2FA açık olmalı.** Bu hesap, Pi'nin terminaline giden anahtardır.

### 3. Tekrar çalıştırın

```bash
make remote
```

Tünel `code-tunnel` adlı systemd servisi olarak kurulur; Pi yeniden başlasa da açılır.
Çıktının sonunda bağlantı adresi yazar: <https://vscode.dev/tunnel/pilabs03>

### 4. Pi Connect girişi (yedek erişim, bir kez)

```bash
ssh padawan@192.168.50.250
rpi-connect signin
```

Çıkan linki açıp Raspberry Pi ID hesabınıza bağlayın (hesapta 2FA'yı açın).

## Bağlanma

| Nereden | Nasıl |
|---|---|
| Herhangi bir tarayıcı | <https://vscode.dev/tunnel/pilabs03> → GitHub ile giriş |
| Masaüstü VS Code | **Remote - Tunnels** eklentisi → Remote Explorer → `pilabs03` |

Açılınca **File → Open Folder → `/home/padawan/playgrounds`**, terminal için **Terminal → New Terminal**.

## Günlük kullanım

### Arayüzleri açmak

```bash
lab-ui                  # hepsini aç
lab-ui grafana argocd   # sadece seçilenler
lab-ui -l               # liste ve portlar
```

VS Code alt paneldeki **Ports** sekmesinde portlar görünür; 🌐 simgesine tıklayınca tarayıcıda
açılır. vscode.dev'de adres `https://xxxx-3000.euw.devtunnels.ms` gibidir ve **yalnızca sizin
GitHub hesabınızla** açılır. Durdurmak için terminalde `Ctrl+C`.

### Kısayollar

Terminalde hazır gelir (`/usr/local/share/homelab/aliases.sh`):

| Kısayol | Ne yapar |
|---|---|
| `k` | `kubectl` (tab tamamlama çalışır) |
| `kgn` | Node'lar ve rolleri |
| `kgp` | Tüm pod'lar |
| `kapps` | ArgoCD uygulamalarının durumu |
| `kev` | Son 30 cluster olayı |
| `pf-grafana` | Grafana → <http://localhost:3000> |
| `pf-argocd` | ArgoCD → <http://localhost:8080> |
| `pf-prometheus` | Prometheus → <http://localhost:9090> |
| `pf-alertmanager` | Alertmanager → <http://localhost:9093> |
| `pf-n8n` | n8n → <http://localhost:5678> |
| `pf-all` | Hepsi (`lab-ui`) |
| `pw-grafana` | Grafana `admin` şifresi |
| `pw-argocd` | ArgoCD `admin` şifresi |
| `awsl` | Floci'ye yönlendirilmiş `aws` (ör. `awsl s3 ls`) |

`aws` için bir kez `aws configure` çalıştırıp access/secret key olarak `test` / `test` girin.

Yeni bir arayüz eklemek için: `ansible/roles/workstation/files/lab-ui` içindeki `UI` listesine
satır ekleyin, kısayolunu `templates/aliases.sh.j2`'ye yazın, `make remote`.

### Diğer Pi'ler

```bash
ssh pilabs01        # şifresiz, ~/.ssh/config hazır
ssh pilabs02
```

### Değişiklikleri göndermek

`~/playgrounds` normal bir git klonudur. Push için GitHub'a kimlik doğrulaması gerekir;
en kolayı VS Code'un **Source Control** panelinden GitHub hesabınızla push etmek.

> Repo **public**. Token, şifre veya şirkete ait bilgi commit etmeyin.

## Güvenlik

- **GitHub hesabı = lab'ın anahtarı.** 2FA (tercihen passkey) şart. Şüpheli bir durumda:
  GitHub → Settings → Applications → **Visual Studio Code** yetkisini kaldırın.
- Port yönlendirmeleri varsayılan olarak **private**'tır. Ports sekmesinde bir portu
  "Public" yapmayın; yaparsanız o arayüz linki bilen herkese açılır.
- Tünel sadece pilabs03'e açılır; diğer Pi'lere oradan SSH ile geçilir.
- n8n webhook'ları gibi **internetten gelen** trafik bu yolla çalışmaz; ona ileride
  Cloudflare Tunnel eklenir.

## Sorun giderme

| Belirti | Kontrol |
|---|---|
| vscode.dev "tunnel not found / offline" | pilabs03'te: `systemctl --user status code-tunnel`, `code tunnel service log` |
| `make remote` girişte duruyor | Kurulum 2. adım; `code tunnel user show` ile kontrol edin |
| Tünel açılmıyor, Pi'ye hiç erişim yok | Yedek: <https://connect.raspberrypi.com> → pilabs01 → Remote shell → `ssh pilabs03` |
| `lab-ui`: "servisi yok, atlandı" | Uygulama henüz kurulmamış: `kapps`; servis adları: `k get svc -A` |
| Port-forward kendiliğinden kapandı | Pod yeniden başlamıştır; komutu tekrar çalıştırın |
| `kubectl`: connection refused | pilabs01 ayakta mı: `ssh pilabs01 'sudo systemctl status k3s'` |
| Şirket ağında vscode.dev açılmıyor | Web filtresi `*.devtunnels.ms` / `vscode.dev`'i engelliyor olabilir |

## Kaldırma

```bash
# pilabs03
code tunnel service uninstall
code tunnel user logout

# pilabs01
rpi-connect signout && rpi-connect off
```

İkisini tamamen kapatmak için `hosts.yml`'deki `vscode_tunnel` / `pi_connect` gruplarını da boşaltın.
