# Play with Containers - Microservices Architecture

## 📋 Table des matières

- [Description du projet](#description-du-projet)
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation et configuration](#installation-et-configuration)
- [Utilisation](#utilisation)
- [Services et endpoints](#services-et-endpoints)
- [Tests avec Postman](#tests-avec-postman)
- [Gestion de l'infrastructure](#gestion-de-linfrastructure)
- [Dépannage](#dépannage)
- [Concepts clés](#concepts-clés)

---

## 📖 Description du projet

Ce projet implémente une architecture de **microservices** utilisant Docker et Docker Compose. Il comprend :

- **2 applications Node.js** : Inventory et Billing
- **2 bases de données PostgreSQL** : Une pour chaque application
- **1 file d'attente RabbitMQ** : Pour la communication asynchrone
- **1 API Gateway** : Point d'entrée unique pour toutes les requêtes externes

L'ensemble de l'infrastructure est conteneurisée avec Docker et orchestrée avec Docker Compose.

---

## 🏗️ Architecture

```
Client (Port 3000)
       ↓
   API Gateway ←→ RabbitMQ ←→ Billing App (Port 8081)
       ↓                           ↓
  Inventory App (Port 8080)   Billing DB (Port 5433)
       ↓
  Inventory DB (Port 5432)
```

### Services déployés :

| Service | Container | Port Interne | Port Externe | Description |
|---------|-----------|--------------|--------------|-------------|
| **api-gateway-app** | api-gateway-app | 3000 | 3000 | Point d'entrée unique |
| **inventory-app** | inventory-app | 8080 | 8080 | Gestion des films |
| **billing-app** | billing-app | 8080 | 8081 | Gestion de la facturation |
| **inventory-db** | inventory-db | 5432 | 5432 | Base PostgreSQL Inventory |
| **billing-db** | billing-db | 5432 | 5433 | Base PostgreSQL Billing |
| **rabbit-queue** | rabbit-queue | 5672/15672 | 5673/15673 | File d'attente RabbitMQ |

---

## 🔧 Prérequis

### Système requis :
- **Linux** (Ubuntu 20.04+ recommandé)
- **Docker** version 20.10+
- **Docker Compose** version 2.0+
- **Git** pour cloner le projet

### Installation des prérequis :
```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation de Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Installation de Docker Compose
sudo apt install docker-compose-plugin -y

# Redémarrer la session pour appliquer les groupes
newgrp docker
```

### Vérification :
```bash
docker --version
docker compose version
```

---

## ⚙️ Installation et configuration

### 1. Cloner le projet
```bash
git clone <votre-repo>
cd play-with-containers
```

### 2. Configuration des variables d'environnement
Créer le fichier `.env` à la racine du projet :

```bash
# Base de données Inventory
INVENTORY_DB_NAME=inventory_db
INVENTORY_DB_USER=inventory_user
INVENTORY_DB_PASSWORD=inventory_secure_password

# Base de données Billing
BILLING_DB_NAME=billing_db
BILLING_DB_USER=billing_user
BILLING_DB_PASSWORD=billing_secure_password

# RabbitMQ
RABBITMQ_USER=rabbit_user
RABBITMQ_PASSWORD=rabbit_secure_password
RABBITMQ_QUEUE=billing_queue
```

**⚠️ Important** : Le fichier `.env` est dans `.gitignore` pour des raisons de sécurité.

### 3. Structure du projet
```
play-with-containers/
├── docker-compose.yml
├── .env
├── .gitignore
├── README.md
├── dockerfiles/
│   ├── inventory-db/
│   │   └── Dockerfile
│   ├── billing-db/
│   │   └── Dockerfile
│   └── rabbitmq/
│       └── Dockerfile
└── srcs/
    ├── inventory-app/
    │   ├── Dockerfile
    │   └── [code source]
    ├── billing-app/
    │   ├── Dockerfile
    │   └── [code source]
    └── api-gateway/
        ├── Dockerfile
        └── [code source]
```

---

## 🚀 Utilisation

### Démarrage de l'infrastructure
```bash
# Construction et démarrage de tous les services
docker compose up --build -d

# Vérifier le statut
docker compose ps
```

### Arrêt de l'infrastructure
```bash
# Arrêt des conteneurs
docker compose down

# Arrêt avec suppression des volumes (⚠️ perte de données)
docker compose down -v
```

### Reconstruction après modifications
```bash
# Reconstruction complète
docker compose down
docker compose build --no-cache
docker compose up -d
```

---

## 🌐 Services et endpoints

### API Gateway (Port 3000)
**Point d'accès unique** : `http://localhost:3000`

#### Endpoints Inventory :
- `GET /api/movies` - Récupérer tous les films
- `POST /api/movies` - Ajouter un nouveau film
- `GET /api/movies/:id` - Récupérer un film par ID
- `PUT /api/movies/:id` - Modifier un film
- `DELETE /api/movies/:id` - Supprimer un film

#### Endpoints Billing :
- `GET /api/billing` - Récupérer toutes les factures
- `POST /api/billing` - Créer une nouvelle facture
- `GET /api/billing/:id` - Récupérer une facture par ID

#### Endpoints de santé :
- `GET /health` - Santé de l'API Gateway
- `GET /api/inventory/health` - Santé du service Inventory
- `GET /api/billing/health` - Santé du service Billing

---

## 🧪 Tests avec Postman

### Test 1 : Ajouter un film (Inventory)
```http
POST http://localhost:3000/api/movies
Content-Type: application/json

{
  "title": "A new movie",
  "description": "Very short description"
}
```
**Réponse attendue** : Status 200 + détails du film créé

### Test 2 : Récupérer les films
```http
GET http://localhost:3000/api/movies
```
**Réponse attendue** : Status 200 + liste des films JSON

### Test 3 : Créer une facture (Billing)
```http
POST http://localhost:3000/api/billing
Content-Type: application/json

{
  "user_id": "20",
  "number_of_items": "99",
  "total_amount": "250"
}
```
**Réponse attendue** : Status 200 + détails de la facture

### Test 4 : Résilience (Billing app arrêtée)
```bash
# Arrêter le service billing
docker compose stop billing-app

# Tester la création d'une facture
POST http://localhost:3000/api/billing
Content-Type: application/json

{
  "user_id": "22",
  "number_of_items": "10",
  "total_amount": "50"
}
```
**Réponse attendue** : Status 200 (grâce à RabbitMQ, le message est mis en queue)

---

## 🛠️ Gestion de l'infrastructure

### Commandes Docker utiles

#### Vérifier les conteneurs
```bash
docker compose ps
docker ps -a
```

#### Vérifier les images
```bash
docker images
```

#### Vérifier les volumes
```bash
docker volume ls
```

#### Vérifier les réseaux
```bash
docker network ls
```

#### Logs des services
```bash
# Logs de tous les services
docker compose logs

# Logs d'un service spécifique
docker compose logs inventory-app
docker compose logs -f billing-app  # En temps réel
```

#### Accéder à un conteneur
```bash
# Shell dans un conteneur
docker compose exec inventory-app bash
docker compose exec inventory-db psql -U inventory_user -d inventory_db
```

### Politique de redémarrage
Tous les conteneurs sont configurés avec `restart: on-failure` :
```bash
# Vérifier la politique de redémarrage
docker inspect -f "{{ .HostConfig.RestartPolicy }}" inventory-app
```

### Healthchecks
Tous les services ont des health checks configurés :
```bash
# Vérifier la santé des conteneurs
docker compose ps
# Les conteneurs sains affichent "healthy"
```

---

## 🔍 Dépannage

### Problèmes courants

#### 1. Port déjà utilisé
```bash
# Vérifier les ports utilisés
sudo netstat -tlnp | grep :3000

# Arrêter le processus qui utilise le port
sudo kill -9 <PID>
```

#### 2. Problème de permissions Docker
```bash
# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker
```

#### 3. Conteneurs qui ne démarrent pas
```bash
# Vérifier les logs d'erreur
docker compose logs <service-name>

# Reconstruire le conteneur problématique
docker compose build --no-cache <service-name>
```

#### 4. Base de données non accessible
```bash
# Vérifier la connectivité
docker compose exec inventory-app ping inventory-db

# Vérifier les variables d'environnement
docker compose exec inventory-app env | grep DB
```

#### 5. RabbitMQ non accessible
```bash
# Accéder à l'interface web RabbitMQ
http://localhost:15673
# Identifiants dans le fichier .env
```

---

## 📚 Concepts clés

### 🐳 Conteneurs vs Machines Virtuelles

**Conteneurs** :
- Partagent le noyau de l'OS hôte
- Légers et rapides à démarrer
- Isolation au niveau processus
- Idéaux pour les microservices

**Machines Virtuelles** :
- OS complet pour chaque VM
- Plus lourdes en ressources
- Isolation complète
- Idéales pour différents OS

### 🐋 Docker

**Docker** est une plateforme de conteneurisation qui permet :
- D'empaqueter une application avec ses dépendances
- D'exécuter l'application de manière identique sur tout environnement
- De gérer le cycle de vie des conteneurs

### 📄 Dockerfile

Un **Dockerfile** contient les instructions pour construire une image Docker :
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

### 🖼️ Images Docker

Une **image Docker** est un template en lecture seule qui contient :
- Le système de fichiers
- Les dépendances
- Les métadonnées d'exécution

### 🌐 Réseaux Docker

Les **réseaux Docker** permettent :
- La communication entre conteneurs
- L'isolation réseau
- La résolution DNS automatique

### 💾 Volumes Docker

Les **volumes Docker** sont utilisés pour :
- Persister les données au-delà du cycle de vie du conteneur
- Partager des données entre conteneurs
- Sauvegarder et restaurer des données

### 🧩 Architecture Microservices

**Avantages** :
- Services indépendants et déployables séparément
- Technologies différentes par service
- Scalabilité fine
- Résilience : une panne n'affecte pas tout le système

**vs Architecture Monolithique** :
- Plus complexe à gérer
- Communication réseau entre services
- Nécessite une orchestration

### 📬 Files d'attente (RabbitMQ)

**RabbitMQ** est un message broker qui :
- Permet la communication asynchrone entre services
- Garantit la livraison des messages
- Offre la résilience : les messages persistent même si un service est en panne

**Cas d'usage** :
- Traitement en arrière-plan
- Découplage des services
- Gestion de la charge

---

## 🎯 Points d'audit - Checklist

### ✅ Fichiers requis
- [ ] README.md complet
- [ ] docker-compose.yml
- [ ] Dockerfiles pour chaque service
- [ ] .gitignore (avec .env exclu)
- [ ] Pas de credentials dans Git

### ✅ Architecture
- [ ] 6 conteneurs : 2 DB, 2 Apps, 1 RabbitMQ, 1 Gateway
- [ ] Ports corrects : Gateway (3000), Apps (8080), DBs (5432)
- [ ] Seulement Gateway accessible de l'extérieur

### ✅ Configuration Docker
- [ ] Images basées sur Alpine/Debian
- [ ] Politique de redémarrage `on-failure`
- [ ] Health checks configurés
- [ ] 3 volumes : 2 DB + 1 Gateway logs
- [ ] Réseau Docker custom

### ✅ Fonctionnalités
- [ ] API Movies (GET/POST) fonctionne
- [ ] API Billing (POST) fonctionne
- [ ] Résilience : Billing fonctionne même si billing-app arrêté
- [ ] Variables d'environnement dans .env

---

## 🏆 Bonus implémentés

- ✅ Health checks sur tous les services
- ✅ Politique de redémarrage automatique
- ✅ Logs centralisés dans volumes
- ✅ Interface RabbitMQ accessible
- ✅ Documentation complète avec exemples

---

**Auteur** : [Votre nom]  
**Date** : [Date du projet]  
**Version** : 1.0