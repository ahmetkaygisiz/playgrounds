import javax.jms.*;
import org.apache.activemq.ActiveMQConnectionFactory;

/**
 * ActiveMQ Producer - Configurable message sending rate
 * 
 * Usage: java -cp "activemq-all-*.jar:." Producer <brokerUrl> <queueName> <messageCount> <delayMs>
 * 
 * Examples:
 *   java -cp "activemq-all-*.jar:." Producer tcp://localhost:8616 TEST.QUEUE 100 1000
 *   java -cp "activemq-all-*.jar:." Producer tcp://192.168.56.11:8616 TEST.QUEUE 500 500
 */
public class Producer {

    public static void main(String[] args) {
        if (args.length < 4) {
            System.out.println("Usage: java Producer <brokerUrl> <queueName> <messageCount> <delayMs>");
            System.out.println();
            System.out.println("  brokerUrl    : ActiveMQ broker URL (e.g. tcp://localhost:8616)");
            System.out.println("  queueName    : Queue name (e.g. TEST.QUEUE)");
            System.out.println("  messageCount : Number of messages to send (0 = unlimited)");
            System.out.println("  delayMs      : Delay between messages in milliseconds");
            System.out.println();
            System.out.println("Example: java Producer tcp://localhost:8616 TEST.QUEUE 100 1000");
            return;
        }

        String brokerUrl = args[0];
        String queueName = args[1];
        int messageCount = Integer.parseInt(args[2]);
        long delayMs = Long.parseLong(args[3]);
        boolean unlimited = (messageCount == 0);

        Connection connection = null;

        try {
            // Create connection
            ActiveMQConnectionFactory factory = new ActiveMQConnectionFactory(brokerUrl);
            connection = factory.createConnection();
            connection.start();

            // Create session and producer
            Session session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
            Destination destination = session.createQueue(queueName);
            MessageProducer producer = session.createProducer(destination);
            producer.setDeliveryMode(DeliveryMode.PERSISTENT);

            System.out.println("=== ActiveMQ Producer ===");
            System.out.println("Broker    : " + brokerUrl);
            System.out.println("Queue     : " + queueName);
            System.out.println("Messages  : " + (unlimited ? "unlimited (Ctrl+C to stop)" : messageCount));
            System.out.println("Delay     : " + delayMs + " ms");
            System.out.println("=========================");
            System.out.println();

            int sent = 0;
            while (unlimited || sent < messageCount) {
                sent++;
                String text = "Message-" + sent + " | timestamp=" + System.currentTimeMillis();
                TextMessage message = session.createTextMessage(text);
                message.setIntProperty("messageNumber", sent);

                producer.send(message);
                System.out.println("[SENT] #" + sent + " -> " + text);

                if (delayMs > 0 && (unlimited || sent < messageCount)) {
                    Thread.sleep(delayMs);
                }
            }

            System.out.println();
            System.out.println("Done! Total sent: " + sent);

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
