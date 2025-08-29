const { Sequelize } = require('sequelize');

// Configuration de la base de données
const sequelize = new Sequelize(
  process.env.INVENTORY_DB_NAME || 'movies',
  process.env.INVENTORY_DB_USER || 'inventory_user',
  process.env.INVENTORY_DB_PASSWORD || 'inventory_pass',
  {
    host: process.env.INVENTORY_DB_HOST || 'localhost',
    port: process.env.INVENTORY_DB_PORT || 5432,
    dialect: 'postgres',
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000
    },
    define: {
      timestamps: true,
      underscored: true,
      freezeTableName: true
    }
  }
);

module.exports = { sequelize };