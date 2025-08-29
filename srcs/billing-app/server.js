const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const { sequelize } = require('./app/config/database');
const orderController = require('./app/controllers/orderController');

const app = express();
const PORT = process.env.BILLING_PORT || 8081;

// Middlewares
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK',
    service: 'Billing API',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    database: 'Connected',
    rabbitmq: 'Connected'
  });
});

// API endpoint pour récupérer les commandes (optionnel pour debug)
app.get('/api/orders', async (req, res) => {
  try {
    const Order = require('./app/models/order');
    const orders = await Order.findAll({
      order: [['created_at', 'DESC']]
    });
    
    res.status(200).json({
      success: true,
      count: orders.length,
      data: orders
    });
  } catch (error) {
    console.error('Erreur récupération commandes:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des commandes'
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: err.message || 'Une erreur inattendue s\'est produite'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'L\'endpoint demandé n\'existe pas'
  });
});

// Database connection and RabbitMQ consumer setup
async function startServer() {
  try {
    // Test database connection
    await sequelize.authenticate();
    console.log('✅ Connexion à la base de données réussie');
    
    // Sync database models
    await sequelize.sync({ force: false });
    console.log('✅ Modèles de base de données synchronisés');
    
    // Start RabbitMQ consumer
    await orderController.startRabbitMQConsumer();
    console.log('✅ Consumer RabbitMQ démarré');
    
    // Start server
    app.listen(PORT, () => {
      console.log(`🚀 Billing API démarré sur le port ${PORT}`);
      console.log(`📡 Health check: http://localhost:${PORT}/health`);
      console.log(`💰 Orders API: http://localhost:${PORT}/api/orders`);
      console.log(`📨 En écoute de la queue: ${process.env.RABBITMQ_QUEUE}`);
    });
    
  } catch (error) {
    console.error('❌ Erreur lors du démarrage:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Arrêt du service en cours...');
  await orderController.closeRabbitMQConnection();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('\n🛑 Arrêt du service en cours...');
  await orderController.closeRabbitMQConnection();
  process.exit(0);
});

startServer();