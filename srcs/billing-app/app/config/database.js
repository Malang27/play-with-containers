const { Sequelize } = require('sequelize');

// Configuration de la base de données
const sequelize = new Sequelize(
  process.env.BILLING_DB_NAME || 'orders',
  process.env.BILLING_DB_USER || 'billing_user',
  process.env.BILLING_DB_PASSWORD || 'billing_pass',
  {
    host: process.env.BILLING_DB_HOST || 'localhost',
    port: process.env.BILLING_DB_PORT || 5432,
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