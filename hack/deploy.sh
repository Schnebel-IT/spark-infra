#!/bin/bash

# 🚀 Spark-Infrastruktur Automatisches Deployment
# Für Schnebel-IT - Einfach und sicher!

set -e  # Stoppe bei Fehlern

# Farben für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logo
echo -e "${BLUE}"
echo "  ____                   _      _____ _______"
echo " / ___| _ __   __ _ _ __| | __ |_   _|_   ___|"
echo " \___ \| '_ \ / _\` | '__| |/ /   | |   | |"
echo "  ___) | |_) | (_| | |  |   <    | |   | |"
echo " |____/| .__/ \__,_|_|  |_|\_\   |_|   |_|"
echo "       |_|"
echo -e "${NC}"
echo -e "${GREEN}Spark Infrastructure Deployment für Schnebel-IT${NC}"
echo "=================================================="
echo

# Funktionen
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Überprüfe Systemanforderungen..."
    
    local missing_tools=()
    
    # Terraform prüfen
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    # Ansible prüfen
    if ! command -v ansible &> /dev/null; then
        missing_tools+=("ansible")
    fi
    
    # kubectl prüfen
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Folgende Tools fehlen: ${missing_tools[*]}"
        log_info "Installiere sie mit: sudo apt install -y ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "Alle benötigten Tools sind installiert!"
}

check_config() {
    log_info "Überprüfe Konfiguration..."
    
    # Terraform Config prüfen
    if [ ! -f "terraform/terraform.tfvars" ]; then
        log_error "terraform/terraform.tfvars nicht gefunden!"
        log_info "Kopiere terraform/terraform.tfvars.example nach terraform/terraform.tfvars"
        exit 1
    fi
    
    # Ansible Vault prüfen
    if [ ! -f "ansible/.vault_pass" ]; then
        log_error "ansible/.vault_pass nicht gefunden!"
        log_info "Erstelle die Datei mit: echo 'dein-passwort' > ansible/.vault_pass"
        exit 1
    fi
    
    log_success "Konfiguration ist vollständig!"
}

deploy_infrastructure() {
    log_info "Starte Infrastructure Deployment..."
    
    cd terraform
    
    # Terraform initialisieren
    log_info "Initialisiere Terraform..."
    terraform init
    
    # Plan erstellen
    log_info "Erstelle Terraform Plan..."
    terraform plan -out=tfplan
    
    # User fragen
    echo
    log_warning "Terraform wird jetzt die VMs erstellen."
    read -p "Fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment abgebrochen."
        exit 0
    fi
    
    # Apply ausführen
    log_info "Erstelle VMs... (Das dauert 5-10 Minuten)"
    terraform apply tfplan
    
    cd ..
    log_success "Infrastructure deployment abgeschlossen!"
}

deploy_configuration() {
    log_info "Starte Configuration Deployment..."
    
    cd ansible
    
    # Warten bis VMs bereit sind
    log_info "Warte bis VMs bereit sind... (3 Minuten)"
    sleep 180
    
    # Connectivity testen
    log_info "Teste Verbindung zu VMs..."
    if ! ansible all -m ping --vault-password-file .vault_pass; then
        log_warning "Einige VMs sind noch nicht erreichbar. Warte weitere 2 Minuten..."
        sleep 120
    fi
    
    # Ansible Playbook ausführen
    log_info "Konfiguriere VMs... (Das dauert 15-30 Minuten)"
    ansible-playbook --vault-password-file .vault_pass playbooks/site.yml
    
    cd ..
    log_success "Configuration deployment abgeschlossen!"
}

deploy_kubernetes() {
    log_info "Starte Kubernetes Deployment..."
    
    # Kubeconfig setup
    mkdir -p ~/.kube
    if [ -f "ansible/files/admin.conf" ]; then
        cp ansible/files/admin.conf ~/.kube/config
        log_success "Kubeconfig konfiguriert!"
    else
        log_error "Kubeconfig nicht gefunden!"
        exit 1
    fi
    
    # Kubernetes Manifeste anwenden
    log_info "Deploye Kubernetes Manifeste..."
    kubectl apply -f kubernetes/manifests/
    
    # Monitoring deployen
    log_info "Deploye Monitoring Stack..."
    kubectl apply -f monitoring/
    
    # Warten bis Pods bereit sind
    log_info "Warte bis alle Pods bereit sind..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n spark-monitoring --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=grafana -n spark-monitoring --timeout=300s || true
    
    log_success "Kubernetes deployment abgeschlossen!"
}

show_status() {
    log_info "Zeige Cluster Status..."
    echo
    
    echo "=== Kubernetes Nodes ==="
    kubectl get nodes -o wide
    echo
    
    echo "=== System Pods ==="
    kubectl get pods -A | grep -E "(kube-system|spark-system|spark-monitoring)" | head -20
    echo
    
    echo "=== Services ==="
    kubectl get svc -A | grep -E "(LoadBalancer|NodePort)" | head -10
    echo
    
    echo "=== Spark Infrastructure Status ==="
    echo "🎯 Grafana Monitoring: http://$(kubectl get svc -n spark-monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3000"
    echo "🎯 Kubernetes Dashboard: Folge der Anleitung in EINFACH-STARTEN.md"
    echo "🎯 Docker Registry: http://$(kubectl get svc -n spark-development docker-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):5000"
    echo
}

cleanup() {
    log_warning "Cleanup wird gestartet..."
    
    read -p "Wirklich ALLES löschen? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup abgebrochen."
        exit 0
    fi
    
    # Kubernetes löschen
    log_info "Lösche Kubernetes Ressourcen..."
    kubectl delete -f monitoring/ || true
    kubectl delete -f kubernetes/manifests/ || true
    
    # Terraform destroy
    log_info "Lösche VMs..."
    cd terraform
    terraform destroy -auto-approve
    cd ..
    
    log_success "Cleanup abgeschlossen!"
}

show_help() {
    echo "Spark Infrastructure Deployment Script"
    echo
    echo "Verwendung: $0 [OPTION]"
    echo
    echo "Optionen:"
    echo "  deploy     - Komplettes Deployment (Standard)"
    echo "  terraform  - Nur Infrastructure (VMs)"
    echo "  ansible    - Nur Configuration"
    echo "  kubernetes - Nur Kubernetes"
    echo "  status     - Zeige Cluster Status"
    echo "  cleanup    - Lösche alles"
    echo "  help       - Zeige diese Hilfe"
    echo
}

# Hauptlogik
case "${1:-deploy}" in
    "deploy")
        check_requirements
        check_config
        deploy_infrastructure
        deploy_configuration
        deploy_kubernetes
        show_status
        log_success "🎉 Spark Infrastructure erfolgreich deployed!"
        ;;
    "terraform")
        check_requirements
        check_config
        deploy_infrastructure
        ;;
    "ansible")
        check_requirements
        check_config
        deploy_configuration
        ;;
    "kubernetes")
        check_requirements
        deploy_kubernetes
        show_status
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        log_error "Unbekannte Option: $1"
        show_help
        exit 1
        ;;
esac
