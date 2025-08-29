# Play-with-Containers - Microservices Architecture

## Overview

Ce projet implémente une architecture microservices complète en utilisant Docker et docker-compose. Il s'appuie sur la solution CRUD Master pour créer un système distribué de gestion de films avec facturation asynchrone.

## Architecture

L'architecture se compose de 6 conteneurs principaux :

- **inventory-db** : Base PostgreSQL pour l'inventaire des films (port 5432)
- **billing-db** : Base PostgreSQL pour la facturation (port 5432)
- **rabbit-queue** : Serveur RabbitMQ pour la messagerie asynchrone
- **inventory-app** : API REST Node.js pour la gestion des films (port 8080)
- **billing-app** : Service Node.js consumer RabbitMQ pour la facturation (port 8080)
- **api-gateway-app** : Passerelle API principale exposée publiquement (port 3000)

## Prerequisites

- Docker Engine 20.10+
- Docker Compose V2
- Linux/macOS/Windows avec WSL2
- 4GB RAM disponible
- 10GB espace disque libre

## Configuration

### Variables d'environnement

Le fichier `.env` contient les configurations sensibles :

```bash
# Bases de données
INVENTORY_DB_NAME=movies
INVENTORY_DB_USER=inventory_user
INVENTORY_DB_PASSWORD=secret_inventory_pass123

BILLING_DB_NAME=orders
BILLING_DB_USER=billing_user
BILLING_DB_PASSWORD=secret_billing_pass123

# RabbitMQ
RABBITMQ_USER=rabbitmq_user
RABBITMQ_PASSWORD=secret_rabbitmq_pass123
RABBITMQ_QUEUE=billing_queue

# Application
NODE_ENV=production
```

## Installation et démarrage

### 1. Cloner et préparer le projet

```bash
git clone <repository-url>
cd play-with-containers
```

### 2. Construire et démarrer l'infrastructure

```bash
# Construire toutes les images
docker-compose build

# Démarrer tous les services
docker-compose up -d

# Vérifier le statut
docker-compose ps
```

### 3. Vérifier le déploiement

```bash
# Health checks
curl http://localhost:3000/health
curl http://localhost:8080/health
curl http://localhost:8081/health

# Voir les logs
docker-compose logs -f
```

## Utilisation

### API Endpoints

**API Gateway (seul point d'accès externe)**
- GET `/health` - Health check de la gateway
- GET `/api/movies` - Lister tous les films
- GET `/api/movies?title=keyword` - Rechercher par titre
- GET `/api/movies/:id` - Récupérer un film par ID
- POST `/api/movies` - Créer un nouveau film
- PUT `/api/movies/:id` - Modifier un film
- DELETE `/api/movies/:id` - Supprimer un film
- POST `/api/billing` - Envoyer une commande de facturation

### Exemples d'utilisation

**Créer un film :**
```bash
curl -X POST http://localhost:3000/api/movies \
  -H "Content-Type: application/json" \
  -d '{"title": "Inception", "description": "A mind-bending thriller"}'
```

**Envoyer une commande :**
```bash
curl -X POST http://localhost:3000/api/billing \
  -H "Content-Type: application/json" \
  -d '{"user_id": "123", "number_of_items": "2", "total_amount": "49.99"}'
```

## Gestion de l'infrastructure

### Commandes Docker Compose

```bash
# Démarrer tous les services
docker-compose up -d

# Arrêter tous les services
docker-compose down

# Reconstruire et redémarrer
docker-compose up -d --build

# Voir les logs d'un service spécifique
docker-compose logs -f api-gateway-app

# Arrêter un service spécifique
docker-compose stop billing-app

# Redémarrer un service spécifique
docker-compose restart billing-app

# Supprimer tout (volumes inclus)
docker-compose down -v
```

### Inspection des ressources

```bash
# Lister les conteneurs
docker ps

# Inspecter un conteneur
docker inspect api-gateway-app

# Lister les volumes
docker volume ls

# Lister les réseaux
docker network ls

# Lister les images
docker images
```

## Test de résilience

Le système supporte la résilience RabbitMQ :

```bash
# 1. Arrêter le service billing
docker-compose stop billing-app

# 2. Envoyer une commande (doit réussir)
curl -X POST http://localhost:3000/api/billing \
  -H "Content-Type: application/json" \
  -d '{"user_id": "resilience", "number_of_items": "5", "total_amount": "125.00"}'

# 3. Redémarrer billing
docker-compose start billing-app

# 4. Vérifier que la commande est traitée
sleep 5
curl http://localhost:8081/api/orders
```

## Sécurité

### Politiques de redémarrage
Tous les conteneurs ont la politique `restart: on-failure` pour une haute disponibilité.

### Utilisateurs non-root
Les applications Node.js s'exécutent avec des utilisateurs non-privilegiés.

### Réseau isolé
Seul api-gateway-app est exposé publiquement. Les autres services communiquent via le réseau Docker interne.

## Volumes persistants

- **inventory-database** : Stockage PostgreSQL pour les films
- **billing-database** : Stockage PostgreSQL pour les commandes
- **api-gateway-app** : Logs de la passerelle API

## Monitoring et logs

### Health checks automatiques
Chaque service inclut des health checks pour surveiller son état.

### Logs centralisés
```bash
# Tous les logs
docker-compose logs -f

# Logs d'un service spécifique
docker-compose logs -f inventory-app

# Logs avec timestamps
docker-compose logs -f -t
```

## Dépannage

### Problèmes courants

**Les conteneurs ne démarrent pas :**
```bash
docker-compose down -v
docker system prune -f
docker-compose up -d --build
```

**Erreurs de port :**
Vérifier qu'aucun service local n'utilise les ports 3000, 5432, 5672, 8080, 8081.

**Problèmes de permissions :**
```bash
sudo chown -R $USER:$USER .
```

**Logs d'erreur :**
```bash
docker-compose logs api-gateway-app
docker-compose logs inventory-app
docker-compose logs billing-app
```

## Développement

### Modification du code
Après modification du code source, reconstruire l'image correspondante :
```bash
docker-compose up -d --build inventory-app
```

### Debug mode
Pour debug, utiliser le mode développement :
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## Architecture détaillée

### Communication inter-services
- **API Gateway → Inventory** : HTTP REST
- **API Gateway → Billing** : RabbitMQ (asynchrone)
- **Apps → Databases** : PostgreSQL connexions directes

### Réseau Docker
Tous les services communiquent via le réseau `crud-network` avec résolution DNS automatique.

### Stockage des données
Les données sont persistantes grâce aux volumes Docker, surviant aux redémarrages des conteneurs.

## Licence

MIT License - Voir le fichier LICENSE pour plus de détails.

## Support

Pour signaler des problèmes ou des suggestions d'amélioration, ouvrir une issue dans le repository.