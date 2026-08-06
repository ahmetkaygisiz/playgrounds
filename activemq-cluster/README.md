# ActiveMQ 5.16.x — Network of Brokers (3 Node)
Vagrant + Ubuntu 22.04 

## Gereksinimler

- [Vagrant](https://developer.hashicorp.com/vagrant/downloads) ≥ 2.3
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) ≥ 7.0
- Host RAM: min 4GB boş (3 × 1GB VM + overhead)

## Kurulum

```bash
# 
cd activemq-cluster

#
chmod +x provision/install.sh test/test.sh

# 
vagrant up

# 
vagrant provision broker1
```

## Port Tablosu

| Servis       | Port  | Protokol |
|--------------|-------|----------|
| OpenWire     | 61616 | TCP      |
| STOMP        | 61613 | TCP      |
| Web Konsol   | 8161  | HTTP     |

## Web Konsollar

| Broker  | URL                              | User/Pass     |
|---------|----------------------------------|---------------|
| broker1 | http://192.168.56.11:8161/admin  | admin / admin |
| broker2 | http://192.168.56.12:8161/admin  | admin / admin |
| broker3 | http://192.168.56.13:8161/admin  | admin / admin |

## Test

```bash
# check the cluster status
./test/test.sh

# or with connecting 
vagrant ssh broker1 -- sudo /opt/activemq/bin/activemq query
```

## Dosya Yapısı

```
activemq-cluster/
├── files
│   └── apache-activemq-5.16.7
│   └── activemq-node1.xml
│   └── activemq-node2.xml
│   └── activemq-node3.xml
│   └── jetty.xml
├── java
│	└── build.sh
│	└── Consumer.java
│	└── Producer.java
├── provision
│	└── activemq.xml.tpl
│	└── install.sh
└── test
│	└── test.sh
├── README.md
└── Vagrantfile
└── README.md
```

## Commands

```bash
# VM durumu
vagrant status

# 
vagrant ssh broker1

# 
vagrant ssh broker1 -- sudo systemctl restart activemq

# 
vagrant ssh broker1 -- sudo tail -f /var/lib/activemq/logs/activemq.log

# 
vagrant halt

# 
vagrant destroy -f
```

## Sorun Giderme

**broker'lar not connecting to eachother:**
```bash
# Firewall check
vagrant ssh broker1 -- sudo ufw status
# 
vagrant ssh broker1 -- sudo ss -tlnp | grep 8616
```

**Service not starrting:**
```bash
vagrant ssh broker1 -- sudo journalctl -u activemq -n 50
vagrant ssh broker1 -- sudo cat /var/lib/activemq/logs/activemq-error.log
```

**activemq.xml update:**
```bash
# Host'tan doğrudan kopyala
vagrant ssh broker1 -- sudo tee /opt/activemq/conf/activemq.xml < provision/activemq.xml.tpl
vagrant ssh broker1 -- sudo systemctl restart activemq
```

## Test Cases

export JAVA_HOME="/mnt/c/Ake/Apps/java/current"
export CLASSPATH=""/mnt/c/Ake/workspace/activemq/activemq-cluster/files/apache-activemq-5.16.7/activemq-all-5.16.7.jar":."

**produce message**
```bash
$JAVA_HOME/bin/java Producer tcp://192.168.56.11:8616 TEST.QUEUE 100 1000

=== ActiveMQ Producer ===
Broker    : tcp://192.168.56.11:8616
Queue     : TEST.QUEUE
Messages  : 100
Delay     : 1000 ms
=========================

[SENT] #1 -> Message-1 | timestamp=1785781846885
[SENT] #2 -> Message-2 | timestamp=1785781847913
...

-------

**consume message**
```bash
$JAVA_HOME/bin/java Consumer tcp://192.168.56.11:8616 TEST.QUEUE 100 50

$JAVA_HOME/bin/java Consumer tcp://192.168.56.11:8616 TEST.QUEUE 100 50
=== ActiveMQ Consumer ===
Broker    : tcp://192.168.56.11:8616
Queue     : TEST.QUEUE
Messages  : 100
Delay     : 50 ms (processing time per message)
Prefetch  : 1
=========================

Waiting for messages...

[RECV] #1 <- Message-1 | timestamp=1785781846885
       Processing... (50 ms)
       Done.
[RECV] #2 <- Message-2 | timestamp=1785781847913
       Processing... (50 ms)
       Done.
...