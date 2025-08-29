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
      PORT: 8080
    },
    error_file: '/home/vagrant/.pm2/logs/inventory_app-error.log',
    out_file: '/home/vagrant/.pm2/logs/inventory_app-out.log',
    log_file: '/home/vagrant/.pm2/logs/inventory_app.log'
  }]
}
