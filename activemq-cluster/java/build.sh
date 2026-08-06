#!/bin/bash
# ActiveMQ Tools - Build & Run Script

JAVA_HOME="/mnt/c/Ake/Apps/java/current"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

JAVA="$JAVA_HOME/bin/java"
JAVAC="$JAVA_HOME/bin/javac"

if [ ! -x "$JAVAC" ]; then
    echo "ERROR: JAVA_HOME is wrong"
    echo "javac not found: $JAVAC"
    exit 1
fi

echo "JAVA_HOME: $JAVA_HOME"
"$JAVA" -version 2>&1 | head -n 1
echo ""

ACTIVEMQ_HOME="/mnt/c/Ake/workspace/activemq/activemq-cluster/files/apache-activemq-5.16.7"
CLASSPATH="$ACTIVEMQ_HOME/lib/*:."
echo "=== ActiveMQ Test Tools ==="
echo ""
echo "Compiling..."
"$JAVAC" -cp "$CLASSPATH" Producer.java Consumer.java
if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi
echo "Compilation successful!"
echo ""
echo "=== USAGE ==="
echo ""
echo "--- PRODUCER ---"
echo "$JAVA -cp \"$CLASSPATH\" Producer <brokerUrl> <queueName> <messageCount> <delayMs>"
echo ""
echo "Examples:"
echo "  # Send 100 messages, 1 per second"
echo "  $JAVA -cp \"$CLASSPATH\" Producer tcp://localhost:8616 TEST.QUEUE 100 1000"
echo ""
echo "  # Send 500 messages, no delay (burst)"
echo "  $JAVA -cp \"$CLASSPATH\" Producer tcp://localhost:8616 TEST.QUEUE 500 0"
echo ""
echo "  # Send unlimited messages, 1 every 2 seconds"
echo "  $JAVA -cp \"$CLASSPATH\" Producer tcp://localhost:8616 TEST.QUEUE 0 2000"
echo ""
echo "--- CONSUMER ---"
echo "$JAVA -cp \"$CLASSPATH\" Consumer <brokerUrl> <queueName> <messageCount> <delayMs> [prefetch]"
echo ""
echo "Examples:"
echo "  # Consume 50 messages, 3 second processing delay"
echo "  $JAVA -cp \"$CLASSPATH\" Consumer tcp://localhost:8616 TEST.QUEUE 50 3000"
echo ""
echo "  # Consume unlimited, 5 second delay, prefetch=1"
echo "  $JAVA -cp \"$CLASSPATH\" Consumer tcp://localhost:8616 TEST.QUEUE 0 5000 1"
echo ""
echo "  # Consume 100 messages, no delay (fast consumer)"
echo "  $JAVA -cp \"$CLASSPATH\" Consumer tcp://localhost:8616 TEST.QUEUE 100 0"
echo ""
echo "=== TEST SCENARIOS ==="
echo ""
echo "Scenario 1: Slow consumer test"
echo "  Node1: $JAVA -cp \"$CLASSPATH\" Producer tcp://localhost:8616 TEST.QUEUE 100 100"
echo "  Node3: $JAVA -cp \"$CLASSPATH\" Consumer tcp://localhost:8616 TEST.QUEUE 0 3000"
echo ""
echo "Scenario 2: Cross-node consume"
echo "  Node1: $JAVA -cp \"$CLASSPATH\" Producer tcp://localhost:8616 TEST.QUEUE 50 0"
echo "  Node2: $JAVA -cp \"$CLASSPATH\" Consumer tcp://localhost:8616 TEST.QUEUE 50 1000"
echo "  Node3: $JAVA -cp \"$CLASSPATH\" Consumer tcp://localhost:8616 TEST.QUEUE 50 1000"
echo ""
echo "Scenario 3: Bridge prefetch test"
echo "  Node1: $JAVA -cp \"$CLASSPATH\" Producer tcp://localhost:8616 TEST.QUEUE 300 0"
echo "  (wait 5 seconds)"
echo "  Node3: $JAVA -cp \"$CLASSPATH\" Consumer tcp://localhost:8616 TEST.QUEUE 10 0"
echo "  (check: did all 300 transfer or only 10?)"
