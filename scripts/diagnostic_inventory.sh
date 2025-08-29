#!/bin/bash

# Script de diagnostic pour l'API Inventory
echo "🔍 Diagnostic de l'API Inventory"
echo "================================"

# Vérifier que nous sommes dans la bonne VM
if [ "$(hostname)" != "inventory-vm" ]; then
    echo "❌ Ce script doit être exécuté dans inventory-vm"
    exit 1
fi

echo "1. 📊 Statut des processus PM2"
echo "------------------------------"
sudo pm2 list

echo ""
echo "2. 🔍 Logs de l'application (20 dernières lignes)"
echo "-----------------------------------------------"
sudo pm2 logs inventory_app --lines 20

echo ""
echo "3. 🌐 Ports en écoute"
echo "--------------------"
sudo netstat -tlnp | grep -E "(8080|5432)"

echo ""
echo "4. 🗄️ Statut PostgreSQL"
echo "----------------------"
sudo systemctl status postgresql --no-pager -l

echo ""
echo "5. 🔐 Test de connexion base de données"
echo "--------------------------------------"
if [ -f "/home/vagrant/.env" ]; then
    source /home/vagrant/.env
    export PGPASSWORD=$INVENTORY_DB_PASSWORD
    echo "Test avec utilisateur: $INVENTORY_DB_USER"
    echo "Base de données: $INVENTORY_DB_NAME"
    
    if psql -h localhost -U $INVENTORY_DB_USER -d $INVENTORY_DB_NAME -c "SELECT version();" 2>/dev/null; then
        echo "✅ Connexion PostgreSQL réussie"
        psql -h localhost -U $INVENTORY_DB_USER -d $INVENTORY_DB_NAME -c "SELECT count(*) as movie_count FROM movies;" 2>/dev/null || echo "ℹ️ Table movies pas encore créée"
    else
        echo "❌ Erreur de connexion PostgreSQL"
        echo "Utilisateurs PostgreSQL disponibles:"
        sudo -u postgres psql -c "SELECT usename FROM pg_user;"
        echo "Bases de données disponibles:"
        sudo -u postgres psql -c "SELECT datname FROM pg_database;"
    fi
else
    echo "❌ Fichier .env non trouvé"
fi

echo ""
echo "6. 🧪 Test API local"
echo "------------------"
if curl -s -f http://localhost:8080/health > /dev/null; then
    echo "✅ API accessible localement"
    echo "Réponse health check:"
    curl -s http://localhost:8080/health | head -c 200
    echo ""
else
    echo "❌ API non accessible localement"
    echo "Test détaillé:"
    curl -v http://localhost:8080/health 2>&1 | head -20
fi

echo ""
echo "7. 📁 Structure des fichiers"
echo "---------------------------"
echo "Contenu de /home/vagrant/inventory-app:"
ls -la /home/vagrant/inventory-app/ | head -10

echo ""
echo "Variables d'environnement (.env):"
if [ -f "/home/vagrant/inventory-app/.env" ]; then
    echo "✅ Fichier .env présent"
    echo "Contenu (masqué les mots de passe):"
    sed 's/PASSWORD=.*/PASSWORD=***/' /home/vagrant/inventory-app/.env
else
    echo "❌ Fichier .env manquant"
fi

echo ""
echo "8. 💾 Ressources système"
echo "----------------------"
echo "RAM utilisée:"
free -h

echo "Espace disque:"
df -h /

echo ""
echo "9. 🔥 Firewall et réseau"
echo "----------------------"
echo "Règles UFW:"
sudo ufw status

echo "Interface réseau:"
ip addr show | grep -A 2 "192.168.56"

echo ""
echo "10. 🔧 Actions recommandées"
echo "==========================="

# Vérifications et recommandations
pm2_status=$(sudo pm2 list | grep inventory_app | awk '{print $18}' || echo "stopped")
if [ "$pm2_status" != "online" ]; then
    echo "🔴 L'application n'est pas en ligne dans PM2"
    echo "   ▶️ Essayer: sudo pm2 restart inventory_app"
fi

if ! curl -s -f http://localhost:8080/health > /dev/null; then
    echo "🔴 L'API ne répond pas localement"
    echo "   ▶️ Vérifier les logs: sudo pm2 logs inventory_app"
    echo "   ▶️ Redémarrer: sudo pm2 restart inventory_app"
fi

if ! sudo netstat -tlnp | grep ":8080" > /dev/null; then
    echo "🔴 Aucun processus n'écoute sur le port 8080"
    echo "   ▶️ Vérifier que l'app démarre: cd /home/vagrant/inventory-app && node server.js"
fi

echo ""
echo "🏁 Diagnostic terminé"