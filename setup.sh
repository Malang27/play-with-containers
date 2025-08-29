#!/bin/bash

# Script d'installation et de gestion pour CRUD Master
# Usage: ./setup.sh [command]

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
PROJECT_NAME="CRUD Master"
GATEWAY_IP="192.168.56.10"
INVENTORY_IP="192.168.56.11"
BILLING_IP="192.168.56.12"

# Fonctions utilitaires
print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}🎬 $PROJECT_NAME - $1${NC}"
    echo -e "${BLUE}===========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Vérifier les prérequis
check_prerequisites() {
    print_header "Vérification des prérequis"
    
    # Vérifier VirtualBox
    if command -v VBoxManage &> /dev/null; then
        VBOX_VERSION=$(VBoxManage --version)
        print_success "VirtualBox installé (version: $VBOX_VERSION)"
    else
        print_error "VirtualBox n'est pas installé"
        echo "Installation: https://www.virtualbox.org/"
        exit 1
    fi
    
    # Vérifier Vagrant
    if command -v vagrant &> /dev/null; then
        VAGRANT_VERSION=$(vagrant --version)
        print_success "Vagrant installé ($VAGRANT_VERSION)"
    else
        print_error "Vagrant n'est pas installé"
        echo "Installation: https://www.vagrantup.com/"
        exit 1
    fi
    
    # Vérifier le fichier .env
    if [ -f ".env" ]; then
        print_success "Fichier .env trouvé"
    else
        print_error "Fichier .env manquant"
        exit 1
    fi
    
    print_success "Tous les prérequis sont installés !"
}

# Créer la structure de répertoires
create_structure() {
    print_header "Création de la structure du projet"
    
    mkdir -p scripts
    mkdir -p srcs/{api-gateway,inventory-app,billing-app}
    mkdir -p srcs/inventory-app/app/{config,models,controllers,routes}
    mkdir -p srcs/billing-app/app/{config,models,controllers}
    mkdir -p docs
    
    print_success "Structure de répertoires créée"
}

# Démarrer toutes les VMs
start_vms() {
    print_header "Démarrage des machines virtuelles"
    
    print_info "Cette opération peut prendre 10-15 minutes..."
    print_info "Démarrage en cours..."
    
    vagrant up
    
    print_success "Toutes les VMs sont démarrées !"
    show_status
}

# Afficher le statut des VMs
show_status() {
    print_header "Statut des machines virtuelles"
    vagrant status
    echo ""
    
    print_info "URLs des services:"
    echo "🌐 Gateway:   http://$GATEWAY_IP:3000"
    echo "🎬 Inventory: http://$INVENTORY_IP:8080"
    echo "💰 Billing:   http://$BILLING_IP:8081"
    echo ""
    
    print_info "Health checks:"
    echo "curl http://$GATEWAY_IP:3000/health"
    echo "curl http://$INVENTORY_IP:8080/health"
    echo "curl http://$BILLING_IP:8081/health"
}

# Tester les APIs
test_apis() {
    print_header "Test des APIs"
    
    print_info "Test de la Gateway..."
    if curl -s -f http://$GATEWAY_IP:3000/health > /dev/null; then
        print_success "Gateway accessible"
    else
        print_error "Gateway non accessible"
    fi
    
    print_info "Test de l'API Inventory..."
    if curl -s -f http://$INVENTORY_IP:8080/health > /dev/null; then
        print_success "API Inventory accessible"
    else
        print_error "API Inventory non accessible"
    fi
    
    print_info "Test de l'API Billing..."
    if curl -s -f http://$BILLING_IP:8081/health > /dev/null; then
        print_success "API Billing accessible"
    else
        print_error "API Billing non accessible"
    fi
    
    echo ""
    print_info "Test fonctionnel - Création d'un film..."
    
    RESPONSE=$(curl -s -X POST http://$GATEWAY_IP:3000/api/movies \
        -H "Content-Type: application/json" \
        -d '{"title":"Test Movie","description":"Film de test créé par le script"}')
    
    if echo "$RESPONSE" | grep -q "success.*true"; then
        print_success "Film créé avec succès via la Gateway"
    else
        print_error "Échec de la création du film"
        echo "Réponse: $RESPONSE"
    fi
    
    print_info "Test fonctionnel - Commande de facturation..."
    
    RESPONSE=$(curl -s -X POST http://$GATEWAY_IP:3000/api/billing \
        -H "Content-Type: application/json" \
        -d '{"user_id":"999","number_of_items":"1","total_amount":"25.99"}')
    
    if echo "$RESPONSE" | grep -q "success.*true"; then
        print_success "Commande envoyée avec succès"
        print_info "Vérifiez la base billing dans quelques secondes..."
    else
        print_error "Échec de l'envoi de la commande"
        echo "Réponse: $RESPONSE"
    fi
}

# Arrêter les VMs
stop_vms() {
    print_header "Arrêt des machines virtuelles"
    vagrant halt
    print_success "Toutes les VMs sont arrêtées"
}

# Redémarrer les VMs
restart_vms() {
    print_header "Redémarrage des machines virtuelles"
    vagrant reload
    print_success "Toutes les VMs ont été redémarrées"
}

# Nettoyer complètement
clean_all() {
    print_header "Nettoyage complet"
    print_warning "Cette action va supprimer toutes les VMs et leurs données !"
    read -p "Êtes-vous sûr ? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        vagrant destroy -f
        print_success "Toutes les VMs ont été supprimées"
    else
        print_info "Nettoyage annulé"
    fi
}

# Afficher les logs des services
show_logs() {
    print_header "Logs des services"
    
    echo "1. Gateway logs:"
    echo "   vagrant ssh gateway-vm -c 'sudo pm2 logs api_gateway --lines 20'"
    echo ""
    echo "2. Inventory logs:"
    echo "   vagrant ssh inventory-vm -c 'sudo pm2 logs inventory_app --lines 20'"
    echo ""
    echo "3. Billing logs:"
    echo "   vagrant ssh billing-vm -c 'sudo pm2 logs billing_app --lines 20'"
    echo ""
    
    read -p "Voulez-vous voir les logs de quelle VM ? (g/i/b/N): " -n 1 -r
    echo
    case $REPLY in
        g|G)
            print_info "Logs de la Gateway:"
            vagrant ssh gateway-vm -c 'sudo pm2 logs api_gateway --lines 20'
            ;;
        i|I)
            print_info "Logs de l'Inventory:"
            vagrant ssh inventory-vm -c 'sudo pm2 logs inventory_app --lines 20'
            ;;
        b|B)
            print_info "Logs du Billing:"
            vagrant ssh billing-vm -c 'sudo pm2 logs billing_app --lines 20'
            ;;
        *)
            print_info "Aucun log affiché"
            ;;
    esac
}

# Test de résilience RabbitMQ
test_resilience() {
    print_header "Test de résilience RabbitMQ"
    
    print_info "1. Arrêt du service billing..."
    vagrant ssh billing-vm -c 'sudo pm2 stop billing_app'
    print_success "Service billing arrêté"
    
    print_info "2. Envoi d'une commande (doit réussir)..."
    RESPONSE=$(curl -s -X POST http://$GATEWAY_IP:3000/api/billing \
        -H "Content-Type: application/json" \
        -d '{"user_id":"resilience_test","number_of_items":"5","total_amount":"100.00"}')
    
    if echo "$RESPONSE" | grep -q "success.*true"; then
        print_success "Commande envoyée avec succès (service arrêté)"
    else
        print_error "Échec de l'envoi de la commande"
    fi
    
    print_info "3. Redémarrage du service billing..."
    vagrant ssh billing-vm -c 'sudo pm2 start billing_app'
    print_success "Service billing redémarré"
    
    print_info "4. Attente du traitement du message (5 secondes)..."
    sleep 5
    
    print_info "5. Vérification en base de données..."
    vagrant ssh billing-vm -c 'export PGPASSWORD=billing_pass && psql -h localhost -U billing_user -d orders -c "SELECT * FROM orders WHERE user_id = '\''resilience_test'\'';"'
}

# SSH vers une VM
ssh_vm() {
    echo "Choisissez une VM:"
    echo "1. Gateway VM"
    echo "2. Inventory VM"
    echo "3. Billing VM"
    read -p "Entrez votre choix (1-3): " choice
    
    case $choice in
        1)
            print_info "Connexion à Gateway VM..."
            vagrant ssh gateway-vm
            ;;
        2)
            print_info "Connexion à Inventory VM..."
            vagrant ssh inventory-vm
            ;;
        3)
            print_info "Connexion à Billing VM..."
            vagrant ssh billing-vm
            ;;
        *)
            print_error "Choix invalide"
            ;;
    esac
}

# Menu principal
show_menu() {
    echo ""
    echo "🎬 $PROJECT_NAME - Menu principal"
    echo ""
    echo "Infrastructure:"
    echo "  1)  start     - Démarrer toutes les VMs"
    echo "  2)  stop      - Arrêter toutes les VMs"
    echo "  3)  restart   - Redémarrer toutes les VMs"
    echo "  4)  status    - Afficher le statut des VMs"
    echo "  5)  clean     - Supprimer toutes les VMs"
    echo ""
    echo "Tests:"
    echo "  6)  test      - Tester toutes les APIs"
    echo "  7)  resilience- Test de résilience RabbitMQ"
    echo ""
    echo "Debug:"
    echo "  8)  logs      - Afficher les logs des services"
    echo "  9)  ssh       - Se connecter à une VM"
    echo ""
    echo "Utilitaires:"
    echo "  10) check     - Vérifier les prérequis"
    echo "  11) init      - Créer la structure du projet"
    echo ""
    echo "  0)  exit      - Quitter"
    echo ""
}

# Fonction principale
main() {
    clear
    print_header "Gestionnaire d'infrastructure"
    
    if [ $# -eq 0 ]; then
        # Mode interactif
        while true; do
            show_menu
            read -p "Votre choix: " choice
            echo ""
            
            case $choice in
                1|start)
                    start_vms
                    ;;
                2|stop)
                    stop_vms
                    ;;
                3|restart)
                    restart_vms
                    ;;
                4|status)
                    show_status
                    ;;
                5|clean)
                    clean_all
                    ;;
                6|test)
                    test_apis
                    ;;
                7|resilience)
                    test_resilience
                    ;;
                8|logs)
                    show_logs
                    ;;
                9|ssh)
                    ssh_vm
                    ;;
                10|check)
                    check_prerequisites
                    ;;
                11|init)
                    create_structure
                    ;;
                0|exit)
                    print_info "Au revoir !"
                    exit 0
                    ;;
                *)
                    print_error "Choix invalide"
                    ;;
            esac
            
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            clear
        done
    else
        # Mode commande directe
        case $1 in
            start)
                start_vms
                ;;
            stop)
                stop_vms
                ;;
            restart)
                restart_vms
                ;;
            status)
                show_status
                ;;
            clean)
                clean_all
                ;;
            test)
                test_apis
                ;;
            resilience)
                test_resilience
                ;;
            logs)
                show_logs
                ;;
            check)
                check_prerequisites
                ;;
            init)
                create_structure
                ;;
            *)
                echo "Usage: $0 [start|stop|restart|status|clean|test|resilience|logs|check|init]"
                exit 1
                ;;
        esac
    fi
}

# Point d'entrée
main "$@"