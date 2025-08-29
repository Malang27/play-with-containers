#!/bin/bash

# Script de configuration pour Inventory VM - Ubuntu 22.04
echo "🚀 Configuration de l'Inventory VM (Ubuntu 22.04) en cours..."

# Mise à jour du système
echo "📦 Mise à jour des paquets..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Installation de Node.js 18.x
echo "📦 Installation de Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Installation de PostgreSQL 14 (Ubuntu 22.04)
echo "📦 Installation de PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

# Installation de PM2
echo "📦 Installation de PM2..."
npm install -g pm2

# Vérification des versions
echo "✅ Versions installées:"
node --version
npm --version
pm2 --version
psql --version

# Configuration de PostgreSQL
echo "🗄️  Configuration de PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Configuration de l'utilisateur PostgreSQL pour inventory
sudo -u postgres psql << EOF
-- Supprimer l'utilisateur s'il existe déjà
DROP USER IF EXISTS ${INVENTORY_DB_USER};
-- Créer l'utilisateur
CREATE USER ${INVENTORY_DB_USER} WITH PASSWORD '${INVENTORY_DB_PASSWORD}';
-- Supprimer la base si elle existe
DROP DATABASE IF EXISTS ${INVENTORY_DB_NAME};
-- Créer la base
CREATE DATABASE ${INVENTORY_DB_NAME} OWNER ${INVENTORY_DB_USER};
-- Donner tous les privilèges
GRANT ALL PRIVILEGES ON DATABASE ${INVENTORY_DB_NAME} TO ${INVENTORY_DB_USER};
-- Pour PostgreSQL 15+, donner accès au schéma public
GRANT ALL ON SCHEMA public TO ${INVENTORY_DB_USER};
\q
EOF

# Configuration de pg_hba.conf pour PostgreSQL 14 (Ubuntu 22.04)
echo "⚙️  Configuration des accès PostgreSQL..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP "PostgreSQL \K[0-9]+")
echo "Version PostgreSQL détectée: $PG_VERSION"

# Configurer pg_hba.conf pour la version détectée
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
sudo -u postgres sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONFIG_DIR/postgresql.conf
echo "host ${INVENTORY_DB_NAME} ${INVENTORY_DB_USER} 127.0.0.1/32 md5" >> $PG_CONFIG_DIR/pg_hba.conf

# Redémarrer PostgreSQL
systemctl restart postgresql

# Test de connexion à la base
echo "🔍 Test de connexion à la base de données..."
export PGPASSWORD=${INVENTORY_DB_PASSWORD}
if psql -h localhost -U ${INVENTORY_DB_USER} -d ${INVENTORY_DB_NAME} -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Connexion PostgreSQL réussie"
else
    echo "❌ Erreur connexion PostgreSQL"
    # Debug PostgreSQL
    systemctl status postgresql
    sudo -u postgres psql -c "SELECT usename FROM pg_user;"
    sudo -u postgres psql -c "SELECT datname FROM pg_database;"
fi

# Configuration des variables d'environnement
echo "⚙️  Configuration des variables d'environnement..."
cat > /home/vagrant/.env << EOF
INVENTORY_PORT=${INVENTORY_PORT}
INVENTORY_DB_HOST=${INVENTORY_DB_HOST}
INVENTORY_DB_PORT=${INVENTORY_DB_PORT}
INVENTORY_DB_NAME=${INVENTORY_DB_NAME}
INVENTORY_DB_USER=${INVENTORY_DB_USER}
INVENTORY_DB_PASSWORD=${INVENTORY_DB_PASSWORD}
NODE_ENV=${NODE_ENV}
EOF

# Copier le fichier .env dans le répertoire de l'application
cp /home/vagrant/.env /home/vagrant/inventory-app/

# Changer le propriétaire des fichiers
chown -R vagrant:vagrant /home/vagrant/inventory-app
chown vagrant:vagrant /home/vagrant/.env

# Installation des dépendances Node.js
echo "📦 Installation des dépendances de l'API Inventory..."
cd /home/vagrant/inventory-app

# Vérifier que package.json existe
if [ ! -f "package.json" ]; then
    echo "❌ package.json non trouvé dans /home/vagrant/inventory-app"
    echo "Contenu du répertoire:"
    ls -la /home/vagrant/inventory-app/
    exit 1
fi

sudo -u vagrant npm install

# Vérifier que server.js existe
if [ ! -f "server.js" ]; then
    echo "❌ server.js non trouvé"
    echo "Contenu du répertoire:"
    ls -la /home/vagrant/inventory-app/
    exit 1
fi

# Configuration de PM2 pour l'utilisateur vagrant
echo "⚙️  Configuration de PM2..."
sudo -u vagrant pm2 startup
env PATH=$PATH:/usr/bin pm2 startup systemd -u vagrant --hp /home/vagrant

# Créer le fichier de configuration PM2
cat > /home/vagrant/inventory-app/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'inventory_app',
    script: './server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    env: {
      NODE_ENV: 'production',
      PORT: ${INVENTORY_PORT}
    },
    error_file: '/home/vagrant/.pm2/logs/inventory_app-error.log',
    out_file: '/home/vagrant/.pm2/logs/inventory_app-out.log',
    log_file: '/home/vagrant/.pm2/logs/inventory_app.log'
  }]
}
EOF

chown vagrant:vagrant /home/vagrant/inventory-app/ecosystem.config.js

# Test de l'application avant de la démarrer avec PM2
echo "🔍 Test de l'application..."
cd /home/vagrant/inventory-app
sudo -u vagrant timeout 10s node server.js &
sleep 3
if curl -f http://localhost:${INVENTORY_PORT}/health > /dev/null 2>&1; then
    echo "✅ Application fonctionne en test"
    pkill -f "node server.js" || true
else
    echo "❌ Application ne répond pas en test"
    echo "Logs de l'application:"
    sudo -u vagrant node server.js &
    sleep 2
    curl -v http://localhost:${INVENTORY_PORT}/health || true
    pkill -f "node server.js" || true
fi

# Démarrer l'application avec PM2
echo "🚀 Démarrage de l'API Inventory avec PM2..."
cd /home/vagrant/inventory-app
sudo -u vagrant pm2 start ecosystem.config.js
sudo -u vagrant pm2 save

# Attendre le démarrage
sleep 5

# Vérifier le statut
echo "📊 Statut des applications:"
sudo -u vagrant pm2 list

# Test final de l'API
echo "🔍 Test final de l'API..."
if curl -f http://localhost:${INVENTORY_PORT}/health > /dev/null 2>&1; then
    echo "✅ API Inventory accessible localement"
else
    echo "❌ API Inventory non accessible"
    echo "Logs PM2:"
    sudo -u vagrant pm2 logs inventory_app --lines 10
    echo "Test de connectivité:"
    sudo netstat -tlnp | grep ${INVENTORY_PORT}
fi

# Configuration du firewall
echo "🔒 Configuration du firewall..."
ufw allow ${INVENTORY_PORT}
ufw allow 5432
ufw --force enable

echo "✅ Configuration de l'Inventory VM terminée!"
echo "🎬 API Inventory disponible sur: http://localhost:${INVENTORY_PORT}"
echo "🗄️  Base de données PostgreSQL configurée: ${INVENTORY_DB_NAME}"
echo "📋 Pour voir les logs: sudo pm2 logs inventory_app"