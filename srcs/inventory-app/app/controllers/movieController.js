const { Op } = require('sequelize');
const Movie = require('../models/movie');

const movieController = {
  // GET /api/movies - Récupérer tous les films
  // GET /api/movies?title=[name] - Rechercher par titre
  getAllMovies: async (req, res) => {
    try {
      const { title } = req.query;
      let whereClause = {};
      
      if (title) {
        whereClause.title = {
          [Op.iLike]: `%${title}%`
        };
      }
      
      const movies = await Movie.findAll({
        where: whereClause,
        order: [['created_at', 'DESC']]
      });
      
      res.status(200).json({
        success: true,
        count: movies.length,
        data: movies
      });
      
    } catch (error) {
      console.error('Erreur getAllMovies:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur lors de la récupération des films',
        message: error.message
      });
    }
  },

  // GET /api/movies/:id - Récupérer un film par ID
  getMovieById: async (req, res) => {
    try {
      const { id } = req.params;
      
      const movie = await Movie.findByPk(id);
      
      if (!movie) {
        return res.status(404).json({
          success: false,
          error: 'Film non trouvé',
          message: `Aucun film trouvé avec l'ID ${id}`
        });
      }
      
      res.status(200).json({
        success: true,
        data: movie
      });
      
    } catch (error) {
      console.error('Erreur getMovieById:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur lors de la récupération du film',
        message: error.message
      });
    }
  },

  // POST /api/movies - Créer un nouveau film
  createMovie: async (req, res) => {
    try {
      const { title, description } = req.body;
      
      if (!title || !description) {
        return res.status(400).json({
          success: false,
          error: 'Données manquantes',
          message: 'Les champs title et description sont requis'
        });
      }
      
      const movie = await Movie.create({
        title: title.trim(),
        description: description.trim()
      });
      
      res.status(201).json({
        success: true,
        message: 'Film créé avec succès',
        data: movie
      });
      
    } catch (error) {
      console.error('Erreur createMovie:', error);
      
      if (error.name === 'SequelizeValidationError') {
        return res.status(400).json({
          success: false,
          error: 'Erreur de validation',
          message: error.errors.map(e => e.message).join(', ')
        });
      }
      
      res.status(500).json({
        success: false,
        error: 'Erreur lors de la création du film',
        message: error.message
      });
    }
  },

  // PUT /api/movies/:id - Mettre à jour un film
  updateMovie: async (req, res) => {
    try {
      const { id } = req.params;
      const { title, description } = req.body;
      
      const movie = await Movie.findByPk(id);
      
      if (!movie) {
        return res.status(404).json({
          success: false,
          error: 'Film non trouvé',
          message: `Aucun film trouvé avec l'ID ${id}`
        });
      }
      
      const updateData = {};
      if (title !== undefined) updateData.title = title.trim();
      if (description !== undefined) updateData.description = description.trim();
      
      await movie.update(updateData);
      
      res.status(200).json({
        success: true,
        message: 'Film mis à jour avec succès',
        data: movie
      });
      
    } catch (error) {
      console.error('Erreur updateMovie:', error);
      
      if (error.name === 'SequelizeValidationError') {
        return res.status(400).json({
          success: false,
          error: 'Erreur de validation',
          message: error.errors.map(e => e.message).join(', ')
        });
      }
      
      res.status(500).json({
        success: false,
        error: 'Erreur lors de la mise à jour du film',
        message: error.message
      });
    }
  },

  // DELETE /api/movies/:id - Supprimer un film
  deleteMovieById: async (req, res) => {
    try {
      const { id } = req.params;
      
      const movie = await Movie.findByPk(id);
      
      if (!movie) {
        return res.status(404).json({
          success: false,
          error: 'Film non trouvé',
          message: `Aucun film trouvé avec l'ID ${id}`
        });
      }
      
      await movie.destroy();
      
      res.status(200).json({
        success: true,
        message: 'Film supprimé avec succès'
      });
      
    } catch (error) {
      console.error('Erreur deleteMovieById:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur lors de la suppression du film',
        message: error.message
      });
    }
  },

  // DELETE /api/movies - Supprimer tous les films
  deleteAllMovies: async (req, res) => {
    try {
      const deletedCount = await Movie.destroy({
        where: {},
        truncate: true
      });
      
      res.status(200).json({
        success: true,
        message: `${deletedCount} films supprimés avec succès`
      });
      
    } catch (error) {
      console.error('Erreur deleteAllMovies:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur lors de la suppression des films',
        message: error.message
      });
    }
  }
};

module.exports = movieController;