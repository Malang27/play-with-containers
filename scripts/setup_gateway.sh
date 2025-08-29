#!/bin/bash

# Script de configuration pour Gateway VM
echo "🚀 Configuration de la Gateway VM en cours..."

# Mise à jour du système
echo "📦 Mise à jour des paquets..."
apt-get update -y
apt-get upgrade -y

# Installation de Node.js 18.x
echo "📦 Installation de Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Installation de PM2 globalement
echo "📦 Installation de PM2..."
npm install -g pm2

# Vérification des versions
echo "✅ Versions installées:"
node --version
npm --version
pm2 --version

# Configuration des variables d'environnement
echo "⚙️  Configuration des variables d'environnement..."
cat > /home/vagrant/.env << EOF
GATEWAY_PORT=${GATEWAY_PORT}
INVENTORY_IP=${INVENTORY_IP}
INVENTORY_PORT=${INVENTORY_PORT}
BILLING_IP=${BILLING_IP}
RABBITMQ_HOST=${RABBITMQ_HOST}
RABBITMQ_PORT=${RABBITMQ_PORT}
RABBITMQ_USER=${RABBITMQ_USER}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
RABBITMQ_QUEUE=${RABBITMQ_QUEUE}
NODE_ENV=${NODE_ENV}
EOF

# Copier le fichier .env dans le répertoire de l'application
cp /home/vagrant/.env /home/vagrant/api-gateway/

# Changer le propriétaire des fichiers
chown -R vagrant:vagrant /home/vagrant/api-gateway
chown vagrant:vagrant /home/vagrant/.env

# Installation des dépendances Node.js
echo "📦 Installation des dépendances de l'API Gateway..."
cd /home/vagrant/api-gateway
sudo -u vagrant npm install

# Configuration de PM2 pour l'utilisateur vagrant
echo "⚙️  Configuration de PM2..."
sudo -u vagrant pm2 startup
env PATH=$PATH:/usr/bin pm2 startup systemd -u vagrant --hp /home/vagrant

# Créer le fichier de configuration PM2
cat > /home/vagrant/api-gateway/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'api_gateway',
    script: './server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '256M',
    env: {
      NODE_ENV: 'production',
      PORT: ${GATEWAY_PORT}
    }
  }]
}
EOF

chown vagrant:vagrant /home/vagrant/api-gateway/ecosystem.config.js

# Démarrer l'application avec PM2
echo "🚀 Démarrage de l'API Gateway..."
cd /home/vagrant/api-gateway
sudo -u vagrant pm2 start ecosystem.config.js
sudo -u vagrant pm2 save

# Vérifier le statut
echo "📊 Statut des applications:"
sudo -u vagrant pm2 list

# Configuration du firewall (optionnel)
echo "🔒 Configuration du firewall..."
ufw allow ${GATEWAY_PORT}
ufw --force enable

echo "✅ Configuration de la Gateway VM terminée!"
echo "🌐 API Gateway disponible sur: http://${GATEWAY_IP}:${GATEWAY_PORT}"
echo "📡 Health check: http://${GATEWAY_IP}:${GATEWAY_PORT}/health"