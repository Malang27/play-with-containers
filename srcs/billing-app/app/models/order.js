const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Order = sequelize.define('orders', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  user_id: {
    type: DataTypes.STRING,
    allowNull: false,
    validate: {
      notEmpty: {
        msg: 'L\'ID utilisateur ne peut pas être vide'
      }
    }
  },
  number_of_items: {
    type: DataTypes.STRING,
    allowNull: false,
    validate: {
      notEmpty: {
        msg: 'Le nombre d\'articles ne peut pas être vide'
      },
      isNumeric: {
        msg: 'Le nombre d\'articles doit être numérique'
      }
    }
  },
  total_amount: {
    type: DataTypes.STRING,
    allowNull: false,
    validate: {
      notEmpty: {
        msg: 'Le montant total ne peut pas être vide'
      },
      isNumeric: {
        msg: 'Le montant total doit être numérique'
      }
    }
  }
}, {
  tableName: 'orders',
  indexes: [
    {
      name: 'orders_user_id_idx',
      fields: ['user_id']
    },
    {
      name: 'orders_created_at_idx',
      fields: ['created_at']
    }
  ]
});

module.exports = Order;