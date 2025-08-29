const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const { sequelize } = require('./app/config/database');
const movieRoutes = require('./app/routes/movieRoutes');

const app = express();
const PORT = process.env.INVENTORY_PORT || 8080;

// Middlewares
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/movies', movieRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK',
    service: 'Inventory API',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    database: 'Connected'
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

// Database connection and server start
async function startServer() {
  try {
    // Test database connection
    await sequelize.authenticate();
    console.log('✅ Connexion à la base de données réussie');
    
    // Sync database models
    await sequelize.sync({ force: false });
    console.log('✅ Modèles de base de données synchronisés');
    
    // Start server
    app.listen(PORT, () => {
      console.log(`🚀 Inventory API démarré sur le port ${PORT}`);
      console.log(`📡 Health check: http://localhost:${PORT}/health`);
      console.log(`🎬 Movies API: http://localhost:${PORT}/api/movies`);
    });
    
  } catch (error) {
    console.error('❌ Erreur lors du démarrage:', error);
    process.exit(1);
  }
}

startServer();