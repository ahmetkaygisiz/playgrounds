#!/usr/bin/env bash
# ============================================================
# ActiveMQ Network of Brokers — Test & Cheatsheet
# activemq-cli ve curl kullanarak cluster doğrulama
# ============================================================

# ── Renk tanımları ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

B1="192.168.56.11"; B2="192.168.56.12"; B3="192.168.56.13"
CRED="admin:admin"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  ActiveMQ Cluster Test Rehberi             ${NC}"
echo -e "${BLUE}============================================${NC}"

# ────────────────────────────────────────────────────────────
# 1. BROKER DURUMU — REST API ile
# ────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[1] Broker durumları (REST API)${NC}"
echo "----------------------------------------------"
for IP in $B1 $B2 $B3; do
  echo -e "${GREEN}→ Broker @ ${IP}${NC}"
  curl -s -u $CRED "http://${IP}:8161/api/jolokia/read/org.apache.activemq:type=Broker,brokerName=*/BrokerName,UptimeMillis,MemoryPercentUsage,StorePercentUsage" \
    | python3 -m json.tool 2>/dev/null || echo "  Bağlantı kurulamadı"
  echo ""
done

# ────────────────────────────────────────────────────────────
# 2. NETWORK CONNECTOR DURUMU — Broker birbirine bağlı mı?
# ────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[2] Network Connector durumları${NC}"
echo "----------------------------------------------"
for IP in $B1 $B2 $B3; do
  echo -e "${GREEN}→ Broker @ ${IP} — aktif bridge'ler:${NC}"
  curl -s -u $CRED \
    "http://${IP}:8161/api/jolokia/search/org.apache.activemq:type=Broker,brokerName=*,connector=networkConnectors,networkConnectorName=*" \
    | python3 -m json.tool 2>/dev/null
  echo ""
done

# ────────────────────────────────────────────────────────────
# 3. KUYRUK LİSTESİ
# ────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[3] Broker1 kuyruk listesi${NC}"
echo "----------------------------------------------"
curl -s -u $CRED \
  "http://${B1}:8161/api/jolokia/search/org.apache.activemq:type=Broker,brokerName=broker1,destinationType=Queue,destinationName=*" \
  | python3 -m json.tool

# ────────────────────────────────────────────────────────────
# 4. MESAJ GÖNDER — broker1'e gönder, broker3'ten oku
#    (Network routing testi)
# ────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[4] Mesaj yönlendirme testi${NC}"
echo "----------------------------------------------"
echo -e "${GREEN}→ broker1'e mesaj gönderiliyor (STOMP / curl):${NC}"

# STOMP protokolüyle mesaj gönder
curl -s -u $CRED \
  -X POST \
  "http://${B1}:8161/api/message/TEST.QUEUE?type=queue&body=Merhaba+Broker1" \
  -H "Content-Type: application/x-www-form-urlencoded"

echo -e "\n${GREEN}→ 2 saniye bekle (mesaj yönlendirme süresi)...${NC}"
sleep 2

echo -e "${GREEN}→ broker3'teki TEST.QUEUE mesaj sayısı:${NC}"
curl -s -u $CRED \
  "http://${B3}:8161/api/jolokia/read/org.apache.activemq:type=Broker,brokerName=broker3,destinationType=Queue,destinationName=TEST.QUEUE/QueueSize,EnqueueCount,DequeueCount" \
  | python3 -m json.tool

# ────────────────────────────────────────────────────────────
# 5. DLQ & İstatistik
# ────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[5] Dead Letter Queue kontrolü${NC}"
echo "----------------------------------------------"
for IP in $B1 $B2 $B3; do
  echo -e "${GREEN}→ Broker @ ${IP}${NC}"
  curl -s -u $CRED \
    "http://${IP}:8161/api/jolokia/read/org.apache.activemq:type=Broker,brokerName=*,destinationType=Queue,destinationName=ActiveMQ.DLQ/QueueSize" \
    2>/dev/null | python3 -m json.tool 2>/dev/null || echo "  DLQ bulunamadı (normal)"
done

# ────────────────────────────────────────────────────────────
# 6. LOG TAKİBİ
# ────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[6] Log takibi komutları${NC}"
echo "----------------------------------------------"
cat << 'EOF'
  # broker1 loglarını takip et:
  vagrant ssh broker1 -- sudo tail -f /var/lib/activemq/logs/activemq.log

  # Network bridge olaylarını filtrele:
  vagrant ssh broker1 -- sudo grep -i "network\|bridge\|connector" /var/lib/activemq/logs/activemq.log

  # Tüm broker'larda hata kontrolü:
  for vm in broker1 broker2 broker3; do
    echo "=== $vm ==="
    vagrant ssh $vm -- sudo grep -i "ERROR\|WARN" /var/lib/activemq/logs/activemq.log | tail -5
  done
EOF

# ────────────────────────────────────────────────────────────
# 7. YARDIMLI KOMUTLAR
# ────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[7] Kullanışlı komutlar${NC}"
echo "----------------------------------------------"
cat << 'EOF'
  # ActiveMQ servisini yeniden başlat:
  vagrant ssh broker1 -- sudo systemctl restart activemq

  # activemq.xml'i düzenle ve uygula:
  vagrant ssh broker1 -- sudo nano /opt/activemq/conf/activemq.xml
  vagrant ssh broker1 -- sudo systemctl restart activemq

  # Kuyruk oluştur ve mesaj gönder (Web konsol):
  http://192.168.56.11:8161/admin  →  admin / admin
  http://192.168.56.12:8161/admin  →  admin / admin
  http://192.168.56.13:8161/admin  →  admin / admin

  # Tüm VM'leri durdur:
  vagrant halt

  # Tüm VM'leri sil:
  vagrant destroy -f
EOF

echo -e "\n${GREEN}Test tamamlandı!${NC}\n"
