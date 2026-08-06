<?xml version="1.0" encoding="UTF-8"?>
<!--
  ActiveMQ 5.16.x — Network of Brokers yapılandırması
  Placeholder'lar install.sh tarafından doldurulur:
    {{BROKER_NAME}}          → broker1 / broker2 / broker3
    {{BROKER_IP}}            → 192.168.56.1x
    {{AMQ_DATA}}             → /var/lib/activemq
    {{NETWORK_CONNECTORS}}   → dinamik olarak üretilen <networkConnector> blokları
-->
<beans
  xmlns="http://www.springframework.org/schema/beans"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.springframework.org/schema/beans
    http://www.springframework.org/schema/beans/spring-beans.xsd
    http://activemq.apache.org/schema/core
    http://activemq.apache.org/schema/core/activemq-core.xsd">

  <!-- ── Broker tanımı ─────────────────────────────────────── -->
  <broker xmlns="http://activemq.apache.org/schema/core"
          brokerName="{{BROKER_NAME}}"
          dataDirectory="{{AMQ_DATA}}/data"
          useJmx="true"
          advisorySupport="false">

    <!-- ── Kalıcılık (KahaDB) ───────────────────────────────── -->
    <persistenceAdapter>
      <kahaDB directory="{{AMQ_DATA}}/data/kahadb"
              journalMaxFileLength="32mb"
              cleanupInterval="30000"
              checkpointInterval="5000"/>
    </persistenceAdapter>

    <!-- ── Transport bağlayıcılar ───────────────────────────── -->
    <transportConnectors>
      <!-- Broker'lar arası + istemci bağlantısı -->
      <transportConnector
          name="openwire"
          uri="tcp://{{BROKER_IP}}:61616?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600"/>
      <!-- STOMP (opsiyonel, curl testi için) -->
      <transportConnector
          name="stomp"
          uri="stomp://{{BROKER_IP}}:61613?maximumConnections=500"/>
    </transportConnectors>

    <!-- ── Network of Brokers bağlantıları ──────────────────── -->
    <networkConnectors>
{{NETWORK_CONNECTORS}}
    </networkConnectors>

    <!-- ── Bellek & depolama limitleri ──────────────────────── -->
    <systemUsage>
      <systemUsage>
        <memoryUsage>
          <memoryUsage limit="256mb"/>
        </memoryUsage>
        <storeUsage>
          <storeUsage limit="1gb"/>
        </storeUsage>
        <tempUsage>
          <tempUsage limit="200mb"/>
        </tempUsage>
      </systemUsage>
    </systemUsage>

    <!-- ── Yönetim ──────────────────────────────────────────── -->
    <managementContext>
      <managementContext createConnector="false"/>
    </managementContext>

    <!-- ── Shutdown hook ────────────────────────────────────── -->
    <shutdownHooks>
      <bean xmlns="http://www.springframework.org/schema/beans"
            class="org.apache.activemq.hooks.SpringContextHook"/>
    </shutdownHooks>

  </broker>

  <!-- ── Web konsol (Jetty) ───────────────────────────────── -->
  <import resource="jetty.xml"/>

</beans>
