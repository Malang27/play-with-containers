#!/bin/bash

# Script de configuration pour Billing VM
echo "🚀 Configuration de la Billing VM en cours..."

# Mise à jour du système
echo "📦 Mise à jour des paquets..."
apt-get update -y
apt-get upgrade -y

# Installation de Node.js 18.x
echo "📦 Installation de Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Installation de PostgreSQL
echo "📦 Installation de PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

# Installation de RabbitMQ
echo "📦 Installation de RabbitMQ..."
apt-get install -y rabbitmq-server

# Installation de PM2
echo "📦 Installation de PM2..."
npm install -g pm2

# Vérification des versions
echo "✅ Versions installées:"
node --version
npm --version
pm2 --version
psql --version
rabbitmqctl version

# Configuration de PostgreSQL
echo "🗄️  Configuration de PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Configuration de l'utilisateur PostgreSQL pour billing
sudo -u postgres psql << EOF
CREATE USER ${BILLING_DB_USER} WITH PASSWORD '${BILLING_DB_PASSWORD}';
CREATE DATABASE ${BILLING_DB_NAME} OWNER ${BILLING_DB_USER};
GRANT ALL PRIVILEGES ON DATABASE ${BILLING_DB_NAME} TO ${BILLING_DB_USER};
\q
EOF

# Configuration de pg_hba.conf pour autoriser les connexions locales
echo "⚙️  Configuration des accès PostgreSQL..."
sudo -u postgres sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/12/main/postgresql.conf
sudo -u postgres echo "host ${BILLING_DB_NAME} ${BILLING_DB_USER} 127.0.0.1/32 md5" >> /etc/postgresql/12/main/pg_hba.conf

# Redémarrer PostgreSQL
systemctl restart postgresql

# Test de connexion à la base
echo "🔍 Test de connexion à la base de données..."
export PGPASSWORD=${BILLING_DB_PASSWORD}
psql -h localhost -U ${BILLING_DB_USER} -d ${BILLING_DB_NAME} -c "SELECT version();"

# Configuration de RabbitMQ
echo "🐰 Configuration de RabbitMQ..."
systemctl start rabbitmq-server
systemctl enable rabbitmq-server

# Attendre que RabbitMQ soit complètement démarré
sleep 10

# Créer l'utilisateur RabbitMQ
rabbitmqctl add_user ${RABBITMQ_USER} ${RABBITMQ_PASSWORD}
rabbitmqctl set_user_tags ${RABBITMQ_USER} administrator
rabbitmqctl set_permissions -p / ${RABBITMQ_USER} ".*" ".*" ".*"

# Activer le plugin de management (optionnel, pour l'interface web)
rabbitmq-plugins enable rabbitmq_management

# Configuration des variables d'environnement
echo "⚙️  Configuration des variables d'environnement..."
cat > /home/vagrant/.env << EOF
BILLING_PORT=${BILLING_PORT}
BILLING_DB_HOST=${BILLING_DB_HOST}
BILLING_DB_PORT=${BILLING_DB_PORT}
BILLING_DB_NAME=${BILLING_DB_NAME}
BILLING_DB_USER=${BILLING_DB_USER}
BILLING_DB_PASSWORD=${BILLING_DB_PASSWORD}
RABBITMQ_HOST=${RABBITMQ_HOST}
RABBITMQ_PORT=${RABBITMQ_PORT}
RABBITMQ_USER=${RABBITMQ_USER}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
RABBITMQ_QUEUE=${RABBITMQ_QUEUE}
NODE_ENV=${NODE_ENV}
EOF

# Copier le fichier .env dans le répertoire de l'application
cp /home/vagrant/.env /home/vagrant/billing-app/

# Changer le propriétaire des fichiers
chown -R vagrant:vagrant /home/vagrant/billing-app
chown vagrant:vagrant /home/vagrant/.env

# Installation des dépendances Node.js
echo "📦 Installation des dépendances de l'API Billing..."
cd /home/vagrant/billing-app
sudo -u vagrant npm install

# Configuration de PM2 pour l'utilisateur vagrant
echo "⚙️  Configuration de PM2..."
sudo -u vagrant pm2 startup
env PATH=$PATH:/usr/bin pm2 startup systemd -u vagrant --hp /home/vagrant

# Créer le fichier de configuration PM2
cat > /home/vagrant/billing-app/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'billing_app',
    script: './server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    env: {
      NODE_ENV: 'production',
      PORT: ${BILLING_PORT}
    }
  }]
}
EOF

chown vagrant:vagrant /home/vagrant/billing-app/ecosystem.config.js

# Démarrer l'application avec PM2
echo "🚀 Démarrage de l'API Billing..."
cd /home/vagrant/billing-app
sudo -u vagrant pm2 start ecosystem.config.js
sudo -u vagrant pm2 save

# Vérifier le statut
echo "📊 Statut des applications:"
sudo -u vagrant pm2 list

# Configuration du firewall
echo "🔒 Configuration du firewall..."
ufw allow ${BILLING_PORT}
ufw allow 5432
ufw allow 5672  # RabbitMQ
ufw allow 15672 # RabbitMQ Management
ufw --force enable

# Test RabbitMQ
echo "🔍 Test de RabbitMQ..."
rabbitmqctl status

echo "✅ Configuration de la Billing VM terminée!"
echo "💰 API Billing disponible sur: http://localhost:${BILLING_PORT}"
echo "🗄️  Base de données PostgreSQL configurée: ${BILLING_DB_NAME}"
echo "🐰 RabbitMQ configuré avec la queue: ${RABBITMQ_QUEUE}"
echo "🌐 RabbitMQ Management: http://localhost:15672 (${RABBITMQ_USER}/${RABBITMQ_PASSWORD})"