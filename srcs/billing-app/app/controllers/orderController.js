const amqp = require('amqplib');
const Order = require('../models/order');

let connection = null;
let channel = null;

const orderController = {
  // Fonction pour créer une nouvelle commande
  createOrder: async (orderData) => {
    try {
      const { user_id, number_of_items, total_amount } = orderData;
      
      // Validation des données
      if (!user_id || !number_of_items || !total_amount) {
        throw new Error('Données manquantes: user_id, number_of_items et total_amount sont requis');
      }
      
      // Créer la commande en base
      const order = await Order.create({
        user_id: user_id.toString(),
        number_of_items: number_of_items.toString(),
        total_amount: total_amount.toString()
      });
      
      console.log('✅ Nouvelle commande créée:', {
        id: order.id,
        user_id: order.user_id,
        number_of_items: order.number_of_items,
        total_amount: order.total_amount
      });
      
      return order;
      
    } catch (error) {
      console.error('❌ Erreur lors de la création de la commande:', error);
      throw error;
    }
  },

  // Démarrer le consumer RabbitMQ
  startRabbitMQConsumer: async () => {
    try {
      const rabbitmqUrl = `amqp://${process.env.RABBITMQ_USER}:${process.env.RABBITMQ_PASSWORD}@${process.env.RABBITMQ_HOST}:${process.env.RABBITMQ_PORT}`;
      
      // Connexion avec retry logic
      let retryCount = 0;
      const maxRetries = 10;
      
      while (retryCount < maxRetries) {
        try {
          connection = await amqp.connect(rabbitmqUrl);
          break;
        } catch (error) {
          retryCount++;
          console.log(`⚠️  Tentative de connexion RabbitMQ ${retryCount}/${maxRetries}...`);
          if (retryCount === maxRetries) {
            throw error;
          }
          await new Promise(resolve => setTimeout(resolve, 5000)); // Attendre 5s
        }
      }
      
      // Gestion des événements de connexion
      connection.on('error', (err) => {
        console.error('❌ Erreur connexion RabbitMQ:', err);
      });
      
      connection.on('close', () => {
        console.log('⚠️  Connexion RabbitMQ fermée');
        connection = null;
        channel = null;
        // Tentative de reconnexion après 5 secondes
        setTimeout(() => {
          console.log('🔄 Tentative de reconnexion RabbitMQ...');
          orderController.startRabbitMQConsumer();
        }, 5000);
      });
      
      // Créer un canal
      channel = await connection.createChannel();
      
      // Déclarer la queue avec durabilité
      const queueName = process.env.RABBITMQ_QUEUE;
      await channel.assertQueue(queueName, { 
        durable: true 
      });
      
      // Configurer le consumer
      await channel.prefetch(1); // Traiter un message à la fois
      
      console.log(`📨 En attente de messages dans la queue: ${queueName}`);
      
      // Consumer callback
      await channel.consume(queueName, async (msg) => {
        if (msg !== null) {
          try {
            const messageContent = msg.content.toString();
            console.log('📥 Message reçu:', messageContent);
            
            // Parser le JSON
            const orderData = JSON.parse(messageContent);
            
            // Créer la commande en base de données
            await orderController.createOrder(orderData);
            
            // Accuser réception du message
            channel.ack(msg);
            console.log('✅ Message traité et acquitté');
            
          } catch (error) {
            console.error('❌ Erreur lors du traitement du message:', error);
            
            // Rejeter le message et le remettre en queue après délai
            setTimeout(() => {
              channel.nack(msg, false, true);
            }, 5000);
          }
        }
      });
      
      console.log('✅ Consumer RabbitMQ configuré avec succès');
      
    } catch (error) {
      console.error('❌ Erreur lors de la configuration du consumer RabbitMQ:', error);
      throw error;
    }
  },

  // Fermer la connexion RabbitMQ proprement
  closeRabbitMQConnection: async () => {
    try {
      if (channel) {
        await channel.close();
        console.log('✅ Canal RabbitMQ fermé');
      }
      
      if (connection) {
        await connection.close();
        console.log('✅ Connexion RabbitMQ fermée');
      }
    } catch (error) {
      console.error('❌ Erreur lors de la fermeture de RabbitMQ:', error);
    }
  },

  // Fonction utilitaire pour obtenir toutes les commandes (debug)
  getAllOrders: async (req, res) => {
    try {
      const orders = await Order.findAll({
        order: [['created_at', 'DESC']]
      });
      
      res.status(200).json({
        success: true,
        count: orders.length,
        data: orders
      });
      
    } catch (error) {
      console.error('Erreur getAllOrders:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur lors de la récupération des commandes',
        message: error.message
      });
    }
  }
};

module.exports = orderController;