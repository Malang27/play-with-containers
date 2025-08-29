# Guide d'audit CRUD Master
## Tests par Postman et Terminal

### Prérequis de l'audit

**Outils nécessaires :**
- VirtualBox ou VMWare
- Vagrant
- Postman
- Terminal avec curl

**Vérifications initiales :**
```bash
vagrant --version
VBoxManage --version
postman --version  # ou vérifier installation GUI
```

---

## 1. Documentation et configuration

### Vérifier le README.md
**Critères d'évaluation :**
- Contexte suffisant pour comprendre le projet
- Instructions d'exécution claires
- Description de la pile technologique
- Architecture expliquée

### Vérifier la configuration des VMs
```bash
cd crud-master
vagrant up
vagrant status
```

**Résultat attendu :**
```
gateway-vm                running (virtualbox)
inventory-vm              running (virtualbox)  
billing-vm                running (virtualbox)
```

### Vérifier les variables d'environnement
```bash
cat .env
```

**Contenu attendu :**
- GATEWAY_IP, INVENTORY_IP, BILLING_IP
- Ports des services
- Credentials PostgreSQL et RabbitMQ
- Pas de credentials en dur dans le code

### Scripts d'installation
```bash
ls -la scripts/
cat scripts/setup_gateway.sh
```

**L'étudiant doit expliquer :**
- Rôle de chaque script
- Pourquoi ces commandes sont utilisées
- Comment l'installation est automatisée

---

## 2. Tests API Inventory via Gateway

### Test POST - Création de film

**Postman :**
- Method: POST
- URL: `http://192.168.56.10:3000/api/movies`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "title": "A new movie",
  "description": "Very short description"
}
```

**Terminal :**
```bash
curl -X POST http://192.168.56.10:3000/api/movies \
  -H "Content-Type: application/json" \
  -d '{"title": "A new movie", "description": "Very short description"}'
```

**Critères de validation :**
- Code de réponse : 200 ou 201
- Réponse JSON avec les données du film créé
- ID généré automatiquement

### Test GET - Récupération des films

**Postman :**
- Method: GET  
- URL: `http://192.168.56.10:3000/api/movies`

**Terminal :**
```bash
curl http://192.168.56.10:3000/api/movies
```

**Critères de validation :**
- Code de réponse : 200
- JSON contenant le film précédemment créé
- Structure de données correcte

### Test de recherche par titre

**Terminal :**
```bash
curl "http://192.168.56.10:3000/api/movies?title=new"
```

### Tests CRUD complets

**Récupérer un film par ID :**
```bash
curl http://192.168.56.10:3000/api/movies/1
```

**Mettre à jour un film :**
```bash
curl -X PUT http://192.168.56.10:3000/api/movies/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated movie", "description": "Updated description"}'
```

**Supprimer un film :**
```bash
curl -X DELETE http://192.168.56.10:3000/api/movies/1
```

### Collection Postman

**Vérifier :**
- Fichier `postman-collection.json` présent
- Import réussi dans Postman
- Toutes les méthodes CRUD présentes
- Variables d'environnement configurées
- Tests automatisés fonctionnels

---

## 3. Vérification base de données Inventory

**Note importante :** Si SSH ne fonctionne pas, utiliser la console VirtualBox.

### Via SSH (si fonctionnel)
```bash
vagrant ssh inventory-vm
sudo -i -u postgres
psql
\l
```

### Via console VirtualBox
1. Double-cliquer sur "CRUD-Inventory-VM"
2. Login: `vagrant` / `vagrant`
3. Exécuter :
```bash
sudo -i -u postgres
psql
\l
```

### Vérifications base de données

**Lister les bases :**
```sql
\l
```
**Critère :** Base `movies` présente

**Se connecter et vérifier la table :**
```sql
\c movies
\dt
TABLE movies;
```

**Critères de validation :**
- Table `movies` existe
- Colonnes : id, title, description, created_at, updated_at
- Données correspondant aux tests effectués

**Vérifier une entrée spécifique :**
```sql
SELECT * FROM movies WHERE title = 'A new movie';
```

---

## 4. Tests API Billing via Gateway

### Test POST - Envoi de commande

**Postman :**
- Method: POST
- URL: `http://192.168.56.10:3000/api/billing`
- Headers: `Content-Type: application/json`
- Body :
```json
{
  "user_id": "20",
  "number_of_items": "99", 
  "total_amount": "250"
}
```

**Terminal :**
```bash
curl -X POST http://192.168.56.10:3000/api/billing \
  -H "Content-Type: application/json" \
  -d '{"user_id": "20", "number_of_items": "99", "total_amount": "250"}'
```

**Critère :** Code de réponse 200

### Test de résilience RabbitMQ

**Arrêter le service billing :**

Via console VirtualBox billing-vm :
```bash
sudo pm2 stop billing_app
sudo pm2 list
```

**Critère :** Status `stopped` pour billing_app

**Envoyer une commande pendant l'arrêt :**
```bash
curl -X POST http://192.168.56.10:3000/api/billing \
  -H "Content-Type: application/json" \
  -d '{"user_id": "22", "number_of_items": "10", "total_amount": "50"}'
```

**Critère :** Réponse 200 même si billing_app arrêté

---

## 5. Vérification base de données Billing

### Accès à la base orders

Via console VirtualBox billing-vm :
```bash
sudo -i -u postgres
psql
\l
```

**Critère :** Base `orders` présente

### Vérifier les commandes
```sql
\c orders
\dt
TABLE orders;
```

**Vérifications attendues :**
- Commande user_id = "20" présente
- Commande user_id = "22" absente (service était arrêté)

**Requêtes de vérification :**
```sql
SELECT * FROM orders WHERE user_id = '20';
SELECT * FROM orders WHERE user_id = '22';
```

### Test de résilience final

**Redémarrer le service billing :**
```bash
sudo pm2 start billing_app
sudo pm2 list
```

**Attendre 5-10 secondes puis vérifier :**
```sql
SELECT * FROM orders WHERE user_id = '22';
```

**Critère :** La commande user_id = "22" doit maintenant apparaître

---

## 6. Tests de santé des services

### Health checks via terminal
```bash
curl http://192.168.56.10:3000/health  # Gateway
curl http://192.168.56.11:8080/health  # Inventory  
curl http://192.168.56.12:8081/health  # Billing
```

### Monitoring PM2

Dans chaque VM :
```bash
sudo pm2 list
sudo pm2 monit
sudo pm2 logs [app-name] --lines 10
```

---

## 7. Tests de charge et robustesse

### Envoi multiple de commandes
```bash
for i in {1..5}; do
  curl -X POST http://192.168.56.10:3000/api/billing \
    -H "Content-Type: application/json" \
    -d "{\"user_id\":\"load_$i\", \"number_of_items\":\"$i\", \"total_amount\":\"$((i*10))\"}" &
done
wait
```

### Création multiple de films
```bash
for i in {1..3}; do
  curl -X POST http://192.168.56.10:3000/api/movies \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Film $i\", \"description\":\"Description $i\"}"
done
```

---

## 8. Checklist de validation finale

**Infrastructure :**
- [ ] 3 VMs opérationnelles
- [ ] Services PM2 actifs
- [ ] Bases PostgreSQL fonctionnelles
- [ ] RabbitMQ opérationnel

**APIs :**
- [ ] Gateway accessible
- [ ] Proxy vers Inventory fonctionnel
- [ ] Communication RabbitMQ vers Billing
- [ ] CRUD complet sur movies
- [ ] Résilience RabbitMQ validée

**Données :**
- [ ] Films créés via Gateway visibles en base
- [ ] Commandes envoyées traitées par Billing
- [ ] Messages traités après redémarrage service

**Documentation :**
- [ ] README complet et clair
- [ ] Collection Postman fournie
- [ ] Variables d'environnement centralisées
- [ ] Code sans credentials hard-codés

---

## 9. Dépannage commun

**Si SSH ne fonctionne pas :**
- Utiliser console VirtualBox uniquement
- Login : vagrant/vagrant

**Si une VM ne répond pas :**
```bash
vagrant halt [vm-name]
vagrant up [vm-name]
```

**Si un service PM2 est arrêté :**
```bash
sudo pm2 restart [app-name]
sudo pm2 logs [app-name]
```

**Si PostgreSQL ne fonctionne pas :**
```bash
sudo systemctl restart postgresql
sudo systemctl status postgresql
```

**Test réseau entre VMs :**
```bash
ping 192.168.56.10  # Gateway
ping 192.168.56.11  # Inventory  
ping 192.168.56.12  # Billing
```

---

## 10. Évaluation des bonnes pratiques

**Architecture :**
- Séparation des préoccupations
- Communication asynchrone (RabbitMQ)
- Proxy pattern (Gateway)
- Database per service

**Sécurité :**
- Credentials externalisés
- Firewall configuré
- Validation des inputs

**Monitoring :**
- Health checks
- Logs centralisés (PM2)
- Gestion d'erreurs

**Déploiement :**
- Infrastructure as Code (Vagrant)
- Scripts d'installation automatisés
- Configuration reproductible