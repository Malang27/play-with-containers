const express = require('express');
const movieController = require('../controllers/movieController');

const router = express.Router();

// GET /api/movies - Récupérer tous les films (avec recherche optionnelle)
router.get('/', movieController.getAllMovies);

// GET /api/movies/:id - Récupérer un film par ID
router.get('/:id', movieController.getMovieById);

// POST /api/movies - Créer un nouveau film
router.post('/', movieController.createMovie);

// PUT /api/movies/:id - Mettre à jour un film
router.put('/:id', movieController.updateMovie);

// DELETE /api/movies/:id - Supprimer un film
router.delete('/:id', movieController.deleteMovieById);

// DELETE /api/movies - Supprimer tous les films
router.delete('/', movieController.deleteAllMovies);

module.exports = router;