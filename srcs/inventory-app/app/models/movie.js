const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Movie = sequelize.define('movies', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  title: {
    type: DataTypes.STRING,
    allowNull: false,
    validate: {
      notEmpty: {
        msg: 'Le titre ne peut pas être vide'
      },
      len: {
        args: [1, 255],
        msg: 'Le titre doit faire entre 1 et 255 caractères'
      }
    }
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: {
        msg: 'La description ne peut pas être vide'
      }
    }
  }
}, {
  tableName: 'movies',
  indexes: [
    {
      name: 'movies_title_idx',
      fields: ['title']
    }
  ]
});

module.exports = Movie;