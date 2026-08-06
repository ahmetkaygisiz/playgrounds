import javax.jms.*;
import org.apache.activemq.ActiveMQConnectionFactory;

/**
 * ActiveMQ Consumer - Configurable message consuming rate
 * 
 * Usage: java -cp "activemq-all-*.jar:." Consumer <brokerUrl> <queueName> <messageCount> <delayMs> [prefetch]
 * 
 * Examples:
 *   java -cp "activemq-all-*.jar:." Consumer tcp://localhost:8616 TEST.QUEUE 100 3000
 *   java -cp "activemq-all-*.jar:." Consumer tcp://192.168.56.13:8616 TEST.QUEUE 0 5000 1
 */
public class Consumer {

    public static void main(String[] args) {
        if (args.length < 4) {
            System.out.println("Usage: java Consumer <brokerUrl> <queueName> <messageCount> <delayMs> [prefetch]");
            System.out.println();
            System.out.println("  brokerUrl    : ActiveMQ broker URL (e.g. tcp://localhost:8616)");
            System.out.println("  queueName    : Queue name (e.g. TEST.QUEUE)");
            System.out.println("  messageCount : Number of messages to consume (0 = unlimited)");
            System.out.println("  delayMs      : Processing delay per message in milliseconds");
            System.out.println("  prefetch     : (Optional) Prefetch size, default=1 for slow consumers");
            System.out.println();
            System.out.println("Example: java Consumer tcp://localhost:8616 TEST.QUEUE 50 3000");
            System.out.println("         (consume 50 messages, 3 seconds between each)");
            return;
        }

        String brokerUrl = args[0];
        String queueName = args[1];
        int messageCount = Integer.parseInt(args[2]);
        long delayMs = Long.parseLong(args[3]);
        int prefetch = args.length >= 5 ? Integer.parseInt(args[4]) : 1;
        boolean unlimited = (messageCount == 0);

        // Add prefetch to broker URL
        String connectionUrl = brokerUrl + "?jms.prefetchPolicy.queuePrefetch=" + prefetch;

        Connection connection = null;

        try {
            // Create connection
            ActiveMQConnectionFactory factory = new ActiveMQConnectionFactory(connectionUrl);
            connection = factory.createConnection();
            connection.start();

            // Create session and consumer
            Session session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
            Destination destination = session.createQueue(queueName);
            MessageConsumer consumer = session.createConsumer(destination);

            System.out.println("=== ActiveMQ Consumer ===");
            System.out.println("Broker    : " + brokerUrl);
            System.out.println("Queue     : " + queueName);
            System.out.println("Messages  : " + (unlimited ? "unlimited (Ctrl+C to stop)" : messageCount));
            System.out.println("Delay     : " + delayMs + " ms (processing time per message)");
            System.out.println("Prefetch  : " + prefetch);
            System.out.println("=========================");
            System.out.println();
            System.out.println("Waiting for messages...");
            System.out.println();

            int consumed = 0;
            while (unlimited || consumed < messageCount) {
                // Wait up to 10 seconds for a message
                Message message = consumer.receive(10000);

                if (message == null) {
                    System.out.println("[TIMEOUT] No message received in 10s, still waiting...");
                    continue;
                }

                consumed++;
                String body = "";
                if (message instanceof TextMessage) {
                    body = ((TextMessage) message).getText();
                } else {
                    body = message.toString();
                }

                System.out.println("[RECV] #" + consumed + " <- " + body);

                // Simulate slow processing
                if (delayMs > 0) {
                    System.out.println("       Processing... (" + delayMs + " ms)");
                    Thread.sleep(delayMs);
                    System.out.println("       Done.");
                }
            }

            System.out.println();
            System.out.println("Done! Total consumed: " + consumed);

        } catch (Exception e) {
            System.err.println("ERROR: " + e.getMessage());
            e.printStackTrace();
        } finally {
            try {
                if (connection != null) connection.close();
            } catch (JMSException e) {
                // ignore
            }
        }
    }
}
