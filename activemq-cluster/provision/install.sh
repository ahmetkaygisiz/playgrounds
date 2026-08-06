#!/usr/bin/env bash
# ============================================================
# ActiveMQ 5.16.7 installation script
# Config files under : files/ 
# home path /opt/servers/activemq
# ============================================================
set -euo pipefail

AMQ_VERSION="5.16.7"
AMQ_BASE="/opt/servers/activemq"
AMQ_USER="activemq"
BINARY="/tmp/apache-activemq-${AMQ_VERSION}-bin.tar.gz"

echo ">>> [${BROKER_NAME}] Installing..."

# 1. Java 
apt-get update -qq
apt-get install -y -qq openjdk-17-jdk-headless
JAVA_BIN=$(readlink -f $(which java))
JAVA_HOME_PATH=$(dirname $(dirname ${JAVA_BIN}))

# - 2. User
id "${AMQ_USER}" &>/dev/null || useradd -r -s /sbin/nologin -d "${AMQ_BASE}" "${AMQ_USER}"

# - 3. Folder Structure
mkdir -p ${AMQ_BASE}/{bin,conf,data,logs,tmp,lib,webapps}

#  4. Binary extracting
echo ">>> Binary extracting"
tar -xzf "${BINARY}" -C /tmp/
AMQ_EXTRACTED="/tmp/apache-activemq-${AMQ_VERSION}"

cp -r ${AMQ_EXTRACTED}/lib/*   ${AMQ_BASE}/lib/
cp -r ${AMQ_EXTRACTED}/bin/*   ${AMQ_BASE}/bin/
cp -r ${AMQ_EXTRACTED}/conf/*  ${AMQ_BASE}/conf/
cp -r ${AMQ_EXTRACTED}/webapps      ${AMQ_BASE}/
cp -r ${AMQ_EXTRACTED}/webapps-demo ${AMQ_BASE}/ 2>/dev/null || true

# - 5. activemq.xml - replace the activemq.confs
NODE_NUM="${BROKER_NAME: -1}" 
cp /tmp/activemq-node${NODE_NUM}.xml ${AMQ_BASE}/conf/activemq.xml

# - 6. activemq.xml set the values as static 
sed -i "s|\${activemq.data}|${AMQ_BASE}/data|g"  ${AMQ_BASE}/conf/activemq.xml
sed -i "s|\${activemq.conf}|${AMQ_BASE}/conf|g"  ${AMQ_BASE}/conf/activemq.xml
sed -i "s|\${activemq.home}|${AMQ_BASE}|g"       ${AMQ_BASE}/conf/activemq.xml
sed -i "s|\${activemq.base}|${AMQ_BASE}|g"       ${AMQ_BASE}/conf/activemq.xml

# - 7. jetty.xml - replace the jetty file
cp /tmp/jetty.xml ${AMQ_BASE}/conf/jetty.xml

# jetty.xml 
sed -i "s|\${activemq.conf}|${AMQ_BASE}/conf|g"  ${AMQ_BASE}/conf/jetty.xml
sed -i "s|\${activemq.home}|${AMQ_BASE}|g"       ${AMQ_BASE}/conf/jetty.xml
sed -i "s|\${activemq.base}|${AMQ_BASE}|g"       ${AMQ_BASE}/conf/jetty.xml

# 0.0.0.0'da dinle
sed -i 's|host="127.0.0.1"|host="0.0.0.0"|g'    ${AMQ_BASE}/conf/jetty.xml

# - 8. /etc/hosts updates
cat >> /etc/hosts << EOF

# ActiveMQ Cluster
192.168.56.11   brokernode1
192.168.56.12   brokernode2
192.168.56.13   brokernode3
EOF

# - 9. env file
cat > /etc/default/activemq << EOF
ACTIVEMQ_HOME=${AMQ_BASE}
ACTIVEMQ_CONF=${AMQ_BASE}/conf
ACTIVEMQ_DATA=${AMQ_BASE}/data
ACTIVEMQ_TMP=${AMQ_BASE}/tmp
ACTIVEMQ_OPTS="-Xms256m -Xmx768m \
  -Djava.net.preferIPv4Stack=true \
  -Dactivemq.conf=${AMQ_BASE}/conf \
  -Dactivemq.data=${AMQ_BASE}/data \
  -Dactivemq.base=${AMQ_BASE} \
  -Dactivemq.home=${AMQ_BASE}"
JAVA_HOME=${JAVA_HOME_PATH}
EOF

# - 10. Permissions -----------------------
chown -R ${AMQ_USER}:${AMQ_USER} ${AMQ_BASE}
chmod +x ${AMQ_BASE}/bin/activemq

# - 11. systemd -----------------------
cat > /etc/systemd/system/activemq.service << EOF
[Unit]
Description=Apache ActiveMQ Message Broker - ${BROKER_NAME}
After=network.target

[Service]
Type=forking
User=${AMQ_USER}
Group=${AMQ_USER}
EnvironmentFile=/etc/default/activemq
ExecStart=${AMQ_BASE}/bin/activemq start
ExecStop=${AMQ_BASE}/bin/activemq stop
PIDFile=${AMQ_BASE}/data/activemq.pid
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable activemq
systemctl start activemq

# - 12. Result 
sleep 5
if systemctl is-active --quiet activemq; then
  echo ">>> [${BROKER_NAME}] Activemq is working!"
  echo "    Web Konsol : http://${BROKER_IP}:8161/admin  (admin/admin)"
  echo "    OpenWire   : tcp://${BROKER_IP}:8616"
else
  echo ">>> [${BROKER_NAME}] FAILED !"
  journalctl -u activemq -n 30 --no-pager
  cat ${AMQ_BASE}/logs/activemq.log 2>/dev/null | tail -30 || true
  exit 1
fi
