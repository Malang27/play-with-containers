# ========================================
# TESTS POSTMAN - LIGNE DE COMMANDE WINDOWS
# ========================================

# 1. TESTS DE SANTÉ DES SERVICES
# ========================================

# Test santé API Gateway
curl -X GET http://localhost:3000/health

# Test santé Inventory via Gateway
curl -X GET http://localhost:3000/api/inventory/health

# Test santé Billing via Gateway  
curl -X GET http://localhost:3000/api/billing/health

# 2. TESTS API INVENTORY (Movies)
# ========================================

# GET - Récupérer tous les films
curl -X GET ^
  -H "Content-Type: application/json" ^
  http://localhost:3000/api/movies

# POST - Ajouter un nouveau film (TEST OBLIGATOIRE AUDIT)
curl -X POST ^
  -H "Content-Type: application/json" ^
  -d "{\"title\": \"A new movie\", \"description\": \"Very short description\"}" ^
  http://localhost:3000/api/movies

# POST - Ajouter un autre film pour test
curl -X POST ^
  -H "Content-Type: application/json" ^
  -d "{\"title\": \"Inception\", \"description\": \"A mind-bending thriller\"}" ^
  http://localhost:3000/api/movies

# GET - Vérifier que les films ont été ajoutés (TEST OBLIGATOIRE AUDIT)
curl -X GET ^
  -H "Content-Type: application/json" ^
  http://localhost:3000/api/movies

# GET - Récupérer un film par ID (remplacer 1 par l'ID du film)
curl -X GET ^
  -H "Content-Type: application/json" ^
  http://localhost:3000/api/movies/1

# PUT - Modifier un film (remplacer 1 par l'ID du film)
curl -X PUT ^
  -H "Content-Type: application/json" ^
  -d "{\"title\": \"Updated Movie\", \"description\": \"Updated description\"}" ^
  http://localhost:3000/api/movies/1

# DELETE - Supprimer un film (remplacer 2 par l'ID du film)
curl -X DELETE ^
  -H "Content-Type: application/json" ^
  http://localhost:3000/api/movies/2

# 3. TESTS API BILLING
# ========================================

# GET - Récupérer toutes les factures
curl -X GET ^
  -H "Content-Type: application/json" ^
  http://localhost:3000/api/billing

# POST - Créer une facture (TEST OBLIGATOIRE AUDIT)
curl -X POST ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\": \"20\", \"number_of_items\": \"99\", \"total_amount\": \"250\"}" ^
  http://localhost:3000/api/billing

# POST - Créer une autre facture
curl -X POST ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\": \"15\", \"number_of_items\": \"5\", \"total_amount\": \"125\"}" ^
  http://localhost:3000/api/billing

# GET - Récupérer une facture par ID (remplacer 1 par l'ID)
curl -X GET ^
  -H "Content-Type: application/json" ^
  http://localhost:3000/api/billing/1

# 4. TEST DE RÉSILIENCE (AUDIT OBLIGATOIRE)
# ========================================

# ÉTAPE 1 : Arrêter le service billing-app
echo "=== ARRÊT DU SERVICE BILLING-APP ==="
docker-compose stop billing-app

# ÉTAPE 2 : Vérifier que le conteneur est arrêté
docker ps | findstr billing-app

# ÉTAPE 3 : Tenter de créer une facture (doit réussir grâce à RabbitMQ)
echo "=== TEST RÉSILIENCE : CRÉATION FACTURE AVEC SERVICE ARRÊTÉ ==="
curl -X POST ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\": \"22\", \"number_of_items\": \"10\", \"total_amount\": \"50\"}" ^
  http://localhost:3000/api/billing

# ÉTAPE 4 : Redémarrer le service billing-app
echo "=== REDÉMARRAGE DU SERVICE BILLING-APP ==="
docker-compose start billing-app

# ÉTAPE 5 : Vérifier que le conteneur est redémarré
docker ps | findstr billing-app

# ÉTAPE 6 : Vérifier que la facture a été traitée
echo "=== VÉRIFICATION : FACTURE TRAITÉE APRÈS REDÉMARRAGE ==="
curl -X GET ^
  -H "Content-Type: application/json" ^
  http://localhost:3000/api/billing

# 5. TESTS DIRECTS SUR LES SERVICES (SI NÉCESSAIRE)
# ========================================

# Test direct Inventory (bypass Gateway)
curl -X GET http://localhost:8080/health
curl -X GET http://localhost:8080/movies

# Test direct Billing (bypass Gateway)
curl -X GET http://localhost:8081/health  
curl -X GET http://localhost:8081/billing

# 6. VÉRIFICATIONS RABBITMQ
# ========================================

# Interface web RabbitMQ (ouvrir dans navigateur)
echo "Interface RabbitMQ : http://localhost:15673"
echo "Identifiants dans le fichier .env"

# 7. TESTS DE CHARGE (BONUS)
# ========================================

# Créer plusieurs films rapidement
for /L %i in (1,1,5) do (
  curl -X POST ^
    -H "Content-Type: application/json" ^
    -d "{\"title\": \"Movie %i\", \"description\": \"Description for movie %i\"}" ^
    http://localhost:3000/api/movies
)

# Créer plusieurs factures rapidement
for /L %i in (1,1,5) do (
  curl -X POST ^
    -H "Content-Type: application/json" ^
    -d "{\"user_id\": \"%i\", \"number_of_items\": \"10\", \"total_amount\": \"100\"}" ^
    http://localhost:3000/api/billing
)

# 8. SURVEILLANCE ET LOGS 
# ========================================

# Surveiller les logs en temps réel
echo "=== LOGS DES SERVICES ==="
docker-compose logs -f --tail=20

# Logs spécifiques par service
docker-compose logs api-gateway-app
docker-compose logs inventory-app  
docker-compose logs billing-app
docker-compose logs rabbit-queue

# 9. SCRIPT DE TEST COMPLET POUR AUDIT
# ========================================

echo "========================================="
echo "DÉMARRAGE DES TESTS POUR AUDIT"
echo "========================================="

echo "1. Test santé des services..."
curl -s http://localhost:3000/health
echo ""

echo "2. Ajout d'un film (test obligatoire)..."
curl -s -X POST -H "Content-Type: application/json" -d "{\"title\": \"A new movie\", \"description\": \"Very short description\"}" http://localhost:3000/api/movies
echo ""

echo "3. Récupération des films (test obligatoire)..."
curl -s http://localhost:3000/api/movies
echo ""

echo "4. Création d'une facture (test obligatoire)..."
curl -s -X POST -H "Content-Type: application/json" -d "{\"user_id\": \"20\", \"number_of_items\": \"99\", \"total_amount\": \"250\"}" http://localhost:3000/api/billing
echo ""

echo "5. Test de résilience..."
docker-compose stop billing-app
curl -s -X POST -H "Content-Type: application/json" -d "{\"user_id\": \"22\", \"number_of_items\": \"10\", \"total_amount\": \"50\"}" http://localhost:3000/api/billing
docker-compose start billing-app
echo ""

echo "========================================="
echo "TESTS TERMINÉS"
echo "========================================="