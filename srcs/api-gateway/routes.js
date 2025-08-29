const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const amqp = require('amqplib');

const router = express.Router();

// Configuration pour le proxy vers l'API Inventory
// Configuration pour le proxy vers l'API Inventory - VERSION CORRIGÉE
const inventoryProxy = createProxyMiddleware('/api/movies', {
  target: `http://${process.env.INVENTORY_IP || 'localhost'}:${process.env.INVENTORY_PORT || 8080}`,
  changeOrigin: true,
  timeout: 30000,
  logLevel: 'debug',
  pathRewrite: {
    '^/api/movies': '/api/movies'
  },
  onProxyReq: (proxyReq, req, res) => {
    // S'assurer que le body est transmis pour les requêtes POST/PUT
    if (req.body && (req.method === 'POST' || req.method === 'PUT')) {
      const bodyData = JSON.stringify(req.body);
      proxyReq.setHeader('Content-Type', 'application/json');
      proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
      proxyReq.write(bodyData);
    }
  },
  onError: (err, req, res) => {
    console.error('Erreur proxy inventory:', err.message);
    res.status(503).json({
      error: 'Service Unavailable',
      message: 'Le service d\'inventaire n\'est pas disponible'
    });
  }
});

// Proxy toutes les requêtes /api/movies vers l'API Inventory
router.use('/api/movies', inventoryProxy);

// Connection RabbitMQ (réutilisable)
let connection = null;
let channel = null;

async function getRabbitMQChannel() {
  try {
    if (!connection) {
      const rabbitmqUrl = `amqp://${process.env.RABBITMQ_USER}:${process.env.RABBITMQ_PASSWORD}@${process.env.RABBITMQ_HOST}:${process.env.RABBITMQ_PORT}`;
      connection = await amqp.connect(rabbitmqUrl);
      
      connection.on('error', (err) => {
        console.error('Erreur connexion RabbitMQ:', err);
        connection = null;
        channel = null;
      });
      
      connection.on('close', () => {
        console.log('Connexion RabbitMQ fermée');
        connection = null;
        channel = null;
      });
    }
    
    if (!channel) {
      channel = await connection.createChannel();
      await channel.assertQueue(process.env.RABBITMQ_QUEUE, { durable: true });
    }
    
    return channel;
  } catch (error) {
    console.error('Erreur lors de la connexion à RabbitMQ:', error);
    throw error;
  }
}

// Endpoint pour l'API Billing via RabbitMQ
router.post('/api/billing', async (req, res) => {
  try {
    // Validation des données
    const { user_id, number_of_items, total_amount } = req.body;
    
    if (!user_id || !number_of_items || !total_amount) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Les champs user_id, number_of_items et total_amount sont requis'
      });
    }

    // Envoi du message à RabbitMQ
    const channel = await getRabbitMQChannel();
    const message = JSON.stringify(req.body);
    
    await channel.sendToQueue(
      process.env.RABBITMQ_QUEUE,
      Buffer.from(message),
      { persistent: true }
    );
    
    console.log('Message envoyé à RabbitMQ:', message);
    
    res.status(200).json({
      success: true,
      message: 'Commande reçue et envoyée pour traitement',
      data: req.body
    });
    
  } catch (error) {
    console.error('Erreur lors de l\'envoi à RabbitMQ:', error);
    res.status(503).json({
      error: 'Service Unavailable',
      message: 'Impossible de traiter la commande pour le moment'
    });
  }
});

// Endpoint d'information sur la gateway
router.get('/api/info', (req, res) => {
  res.json({
    service: 'API Gateway',
    version: '1.0.0',
    endpoints: {
      inventory: '/api/movies',
      billing: '/api/billing',
      health: '/health'
    },
    timestamp: new Date().toISOString()
  });
});

module.exports = router;