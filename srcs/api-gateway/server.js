const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const routes = require('./routes');

const app = express();
const PORT = process.env.GATEWAY_PORT || 3000;

// Middlewares
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/', routes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK',
    service: 'API Gateway',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
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

// Start server
app.listen(PORT, () => {
  console.log(`🚀 API Gateway démarré sur le port ${PORT}`);
  console.log(`📡 Health check disponible sur http://localhost:${PORT}/health`);
  console.log(`🔗 Inventory API proxy: http://localhost:${PORT}/api/movies`);
  console.log(`💰 Billing API endpoint: http://localhost:${PORT}/api/billing`);
});