# -*- mode: ruby -*-
# vi: set ft=ruby :

# Charger les variables d'environnement depuis .env
def load_env_vars
  env_vars = {}
  if File.exist?('.env')
    File.readlines('.env').each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      key, value = line.split('=', 2)
      env_vars[key] = value if key && value
    end
  end
  env_vars
end

env_vars = load_env_vars

Vagrant.configure("2") do |config|
  # Configuration de base
  config.vm.box = "ubuntu/jammy64"  # Ubuntu 22.04 LTS
  config.vm.box_check_update = false
  
  # Configuration SSH simplifiée et corrigée
  config.ssh.insert_key = false
  config.ssh.private_key_path = ["~/.vagrant.d/insecure_private_key"]
  config.ssh.forward_agent = true
  config.ssh.connect_timeout = 300
  config.ssh.shell = "bash -l"
  
  # Forcer l'utilisation de clés SSH insecure
  config.vm.provision "shell", inline: <<-SHELL
    # Configuration SSH pour permettre les connexions
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # S'assurer que les clés vagrant fonctionnent
    mkdir -p /home/vagrant/.ssh
    chmod 700 /home/vagrant/.ssh
    
    # Ajouter la clé publique vagrant
    if [ ! -f /home/vagrant/.ssh/authorized_keys ]; then
      echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" > /home/vagrant/.ssh/authorized_keys
    fi
    
    chmod 600 /home/vagrant/.ssh/authorized_keys
    chown -R vagrant:vagrant /home/vagrant/.ssh
    
    # Redémarrer SSH
    sudo systemctl restart sshd
    sudo systemctl enable sshd
    
    echo "SSH configuration completed"
  SHELL
  
  # Configuration VirtualBox
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.cpus = 1
    vb.linked_clone = true
    # Optimisations pour Windows
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  # VM 1: Gateway
  config.vm.define "gateway-vm" do |gateway|
    gateway.vm.hostname = "gateway-vm"
    gateway.vm.network "private_network", ip: env_vars['GATEWAY_IP'] || "192.168.56.10"
    
    gateway.vm.provider "virtualbox" do |vb|
      vb.name = "CRUD-Gateway-VM"
      vb.memory = "512"
    end
    
    # Synchronisation forcée avec retry
    gateway.vm.synced_folder "./srcs/api-gateway", "/home/vagrant/api-gateway",
      owner: "vagrant", group: "vagrant", mount_options: ["dmode=755,fmode=644"]
    
    # Configuration avec retry SSH et démarrage automatique des services
    gateway.vm.provision "shell", run: "always", inline: <<-SHELL
      echo "Configuration Gateway VM..."
      
      # Installation Node.js si pas déjà fait
      if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
        npm install -g pm2
      fi
      
      # Configuration des variables d'environnement
      cat > /home/vagrant/.env << 'ENVEOF'
GATEWAY_PORT=#{env_vars['GATEWAY_PORT'] || '3000'}
INVENTORY_IP=#{env_vars['INVENTORY_IP'] || '192.168.56.11'}
INVENTORY_PORT=#{env_vars['INVENTORY_PORT'] || '8080'}
BILLING_IP=#{env_vars['BILLING_IP'] || '192.168.56.12'}
RABBITMQ_HOST=#{env_vars['BILLING_IP'] || '192.168.56.12'}
RABBITMQ_PORT=#{env_vars['RABBITMQ_PORT'] || '5672'}
RABBITMQ_USER=#{env_vars['RABBITMQ_USER'] || 'rabbitmq_user'}
RABBITMQ_PASSWORD=#{env_vars['RABBITMQ_PASSWORD'] || 'rabbitmq_pass'}
RABBITMQ_QUEUE=#{env_vars['RABBITMQ_QUEUE'] || 'billing_queue'}
NODE_ENV=#{env_vars['NODE_ENV'] || 'development'}
ENVEOF
      
      # Créer les fichiers de l'application si manquants
      mkdir -p /home/vagrant/api-gateway
      if [ ! -f /home/vagrant/api-gateway/server.js ]; then
        cat > /home/vagrant/api-gateway/server.js << 'SERVEREOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const routes = require('./routes');

const app = express();
const PORT = process.env.GATEWAY_PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/', routes);

app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK',
    service: 'API Gateway',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: err.message || 'Une erreur inattendue est survenue'
  });
});

app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'Endpoint non trouvé'
  });
});

app.listen(PORT, () => {
  console.log(`API Gateway démarré sur le port ${PORT}`);
});
SERVEREOF
      fi

      # Créer package.json si manquant
      if [ ! -f /home/vagrant/api-gateway/package.json ]; then
        cat > /home/vagrant/api-gateway/package.json << 'PKGEOF'
{
  "name": "api-gateway",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1",
    "http-proxy-middleware": "^2.0.6",
    "amqplib": "^0.10.3"
  }
}
PKGEOF
      fi

      # Créer routes.js basique si manquant
      if [ ! -f /home/vagrant/api-gateway/routes.js ]; then
        cat > /home/vagrant/api-gateway/routes.js << 'ROUTESEOF'
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const amqp = require('amqplib');

const router = express.Router();

const inventoryProxy = createProxyMiddleware({
  target: `http://${process.env.INVENTORY_IP || 'localhost'}:${process.env.INVENTORY_PORT || 8080}`,
  changeOrigin: true,
  timeout: 10000,
  onError: (err, req, res) => {
    console.error('Erreur proxy inventory:', err.message);
    res.status(503).json({
      error: 'Service Unavailable',
      message: 'Le service inventaire nest pas disponible'
    });
  }
});

router.use('/api/movies', inventoryProxy);

router.post('/api/billing', async (req, res) => {
  try {
    const { user_id, number_of_items, total_amount } = req.body;
    
    if (!user_id || !number_of_items || !total_amount) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Les champs user_id, number_of_items et total_amount sont requis'
      });
    }

    res.status(200).json({
      success: true,
      message: 'Commande reçue',
      data: req.body
    });
    
  } catch (error) {
    console.error('Erreur billing:', error);
    res.status(503).json({
      error: 'Service Unavailable',
      message: 'Impossible de traiter la commande'
    });
  }
});

router.get('/api/info', (req, res) => {
  res.json({
    service: 'API Gateway',
    version: '1.0.0',
    endpoints: {
      inventory: '/api/movies',
      billing: '/api/billing',
      health: '/health'
    },
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
ROUTESEOF
      fi
      
      cp /home/vagrant/.env /home/vagrant/api-gateway/
      chown -R vagrant:vagrant /home/vagrant/api-gateway
      
      # Installation dépendances
      cd /home/vagrant/api-gateway
      sudo -u vagrant npm install
      
      # Configuration PM2 startup
      sudo -u vagrant pm2 startup
      env PATH=$PATH:/usr/bin pm2 startup systemd -u vagrant --hp /home/vagrant
      
      # Arrêter les processus existants et redémarrer
      sudo -u vagrant pm2 delete api_gateway 2>/dev/null || true
      sudo -u vagrant pm2 start server.js --name api_gateway
      sudo -u vagrant pm2 save
      
      echo "Gateway VM configurée avec démarrage automatique"
    SHELL
  end

  # VM 2: Inventory
  config.vm.define "inventory-vm" do |inventory|
    inventory.vm.hostname = "inventory-vm"
    inventory.vm.network "private_network", ip: env_vars['INVENTORY_IP'] || "192.168.56.11"
    
    inventory.vm.provider "virtualbox" do |vb|
      vb.name = "CRUD-Inventory-VM"
      vb.memory = "1024"
    end
    
    inventory.vm.synced_folder "./srcs/inventory-app", "/home/vagrant/inventory-app",
      owner: "vagrant", group: "vagrant", mount_options: ["dmode=755,fmode=644"]
    
    inventory.vm.provision "shell", run: "always", inline: <<-SHELL
      echo "Configuration Inventory VM..."
      
      # Installation si nécessaire
      if ! command -v node &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs postgresql postgresql-contrib
        npm install -g pm2
        
        # Configuration PostgreSQL
        systemctl start postgresql
        systemctl enable postgresql
        
        sudo -u postgres psql << 'SQLEOF'
DROP DATABASE IF EXISTS movies;
DROP USER IF EXISTS inventory_user;
CREATE USER inventory_user WITH PASSWORD 'inventory_pass';
CREATE DATABASE movies OWNER inventory_user;
GRANT ALL PRIVILEGES ON DATABASE movies TO inventory_user;
SQLEOF
        
        # Configuration accès PostgreSQL
        PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP "PostgreSQL \\K[0-9]+")
        echo "host movies inventory_user 127.0.0.1/32 md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf
        systemctl restart postgresql
      fi
      
      # Variables d'environnement
      cat > /home/vagrant/.env << 'ENVEOF'
INVENTORY_PORT=#{env_vars['INVENTORY_PORT'] || '8080'}
INVENTORY_DB_HOST=localhost
INVENTORY_DB_PORT=5432
INVENTORY_DB_NAME=movies
INVENTORY_DB_USER=inventory_user
INVENTORY_DB_PASSWORD=inventory_pass
NODE_ENV=#{env_vars['NODE_ENV'] || 'development'}
ENVEOF
      
      cp /home/vagrant/.env /home/vagrant/inventory-app/ 2>/dev/null || true
      chown -R vagrant:vagrant /home/vagrant/inventory-app 2>/dev/null || true
      
      # Démarrage application
      cd /home/vagrant/inventory-app
      if [ -f package.json ]; then
        sudo -u vagrant npm install
        sudo -u vagrant pm2 delete inventory_app 2>/dev/null || true
        sudo -u vagrant pm2 start server.js --name inventory_app
        sudo -u vagrant pm2 save
      fi
      
      echo "Inventory VM configurée - SSH accessible !"
    SHELL
  end

  # VM 3: Billing
  config.vm.define "billing-vm" do |billing|
    billing.vm.hostname = "billing-vm"
    billing.vm.network "private_network", ip: env_vars['BILLING_IP'] || "192.168.56.12"
    
    billing.vm.provider "virtualbox" do |vb|
      vb.name = "CRUD-Billing-VM"
      vb.memory = "1024"
    end
    
    billing.vm.synced_folder "./srcs/billing-app", "/home/vagrant/billing-app",
      owner: "vagrant", group: "vagrant", mount_options: ["dmode=755,fmode=644"]
    
    billing.vm.provision "shell", run: "always", inline: <<-SHELL
      echo "Configuration Billing VM..."
      
      # Installation complète si nécessaire
      if ! command -v node &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs postgresql postgresql-contrib rabbitmq-server
        npm install -g pm2
        
        # Configuration PostgreSQL
        systemctl start postgresql
        systemctl enable postgresql
        
        sudo -u postgres psql << 'SQLEOF'
DROP DATABASE IF EXISTS orders;
DROP USER IF EXISTS billing_user;
CREATE USER billing_user WITH PASSWORD 'billing_pass';
CREATE DATABASE orders OWNER billing_user;
GRANT ALL PRIVILEGES ON DATABASE orders TO billing_user;
SQLEOF
        
        PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP "PostgreSQL \\K[0-9]+")
        echo "host orders billing_user 127.0.0.1/32 md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf
        systemctl restart postgresql
        
        # Configuration RabbitMQ
        systemctl start rabbitmq-server
        systemctl enable rabbitmq-server
        sleep 10
        
        rabbitmqctl add_user rabbitmq_user rabbitmq_pass 2>/dev/null || true
        rabbitmqctl set_user_tags rabbitmq_user administrator
        rabbitmqctl set_permissions -p / rabbitmq_user ".*" ".*" ".*"
        rabbitmq-plugins enable rabbitmq_management
      fi
      
      # Variables d'environnement
      cat > /home/vagrant/.env << 'ENVEOF'
BILLING_PORT=#{env_vars['BILLING_PORT'] || '8081'}
BILLING_DB_HOST=localhost
BILLING_DB_PORT=5432
BILLING_DB_NAME=orders
BILLING_DB_USER=billing_user
BILLING_DB_PASSWORD=billing_pass
RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USER=rabbitmq_user
RABBITMQ_PASSWORD=rabbitmq_pass
RABBITMQ_QUEUE=billing_queue
NODE_ENV=#{env_vars['NODE_ENV'] || 'development'}
ENVEOF
      
      cp /home/vagrant/.env /home/vagrant/billing-app/ 2>/dev/null || true
      chown -R vagrant:vagrant /home/vagrant/billing-app 2>/dev/null || true
      
      # Démarrage application
      cd /home/vagrant/billing-app
      if [ -f package.json ]; then
        sudo -u vagrant npm install
        sudo -u vagrant pm2 delete billing_app 2>/dev/null || true
        sudo -u vagrant pm2 start server.js --name billing_app
        sudo -u vagrant pm2 save
      fi
      
      echo "Billing VM configurée - SSH accessible !"
    SHELL
  end
end