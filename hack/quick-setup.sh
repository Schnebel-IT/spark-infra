#!/bin/bash

# 🚀 Spark Infrastructure - Quick Setup für Proxmox Community Edition
# Installiert automatisch alle benötigten Tools
# MUSS ALS ROOT AUSGEFÜHRT WERDEN!

set -e

# Root-Check
if [ "$EUID" -ne 0 ]; then
    echo "❌ Dieses Script muss als root ausgeführt werden!"
    echo "Verwende: sudo ./hack/quick-setup.sh"
    exit 1
fi

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Spark Infrastructure - Quick Setup für Proxmox CE${NC}"
echo "=================================================="
echo

# Proxmox Version prüfen
echo -e "${YELLOW}📋 Prüfe Proxmox-System...${NC}"
if [ -f /etc/pve/.version ]; then
    PVE_VERSION=$(cat /etc/pve/.version)
    echo -e "${GREEN}✅ Proxmox VE ${PVE_VERSION} erkannt${NC}"
else
    echo -e "${YELLOW}⚠️  Proxmox VE nicht erkannt - fahre trotzdem fort${NC}"
fi

# System updaten
echo -e "${YELLOW}📦 Aktualisiere Proxmox-System...${NC}"
apt update && apt upgrade -y

# Grundlegende Tools installieren
echo -e "${YELLOW}🛠️  Installiere grundlegende Tools...${NC}"
apt install -y curl wget git python3 python3-pip unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Terraform installieren
echo -e "${YELLOW}🏗️  Installiere Terraform...${NC}"
if ! command -v terraform &> /dev/null; then
    TERRAFORM_VERSION="1.6.0"
    wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -O /tmp/terraform.zip
    unzip /tmp/terraform.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/terraform
    rm /tmp/terraform.zip
    echo -e "${GREEN}✅ Terraform ${TERRAFORM_VERSION} installiert!${NC}"
else
    echo -e "${GREEN}✅ Terraform bereits installiert!${NC}"
fi

# Ansible installieren
echo -e "${YELLOW}⚙️  Installiere Ansible...${NC}"
if ! command -v ansible &> /dev/null; then
    # Für Proxmox: Ansible system-wide installieren
    pip3 install ansible ansible-vault
    # Proxmox-spezifische Ansible-Module
    pip3 install proxmoxer requests
    echo -e "${GREEN}✅ Ansible mit Proxmox-Support installiert!${NC}"
else
    echo -e "${GREEN}✅ Ansible bereits installiert!${NC}"
fi

# kubectl installieren
echo -e "${YELLOW}☸️  Installiere kubectl...${NC}"
if ! command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
    chmod +x /usr/local/bin/kubectl
    echo -e "${GREEN}✅ kubectl ${KUBECTL_VERSION} installiert!${NC}"
else
    echo -e "${GREEN}✅ kubectl bereits installiert!${NC}"
fi

# Helm installieren
echo -e "${YELLOW}🎯 Installiere Helm...${NC}"
if ! command -v helm &> /dev/null; then
    # Helm über Script installieren (einfacher für Proxmox)
    curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 /tmp/get_helm.sh
    /tmp/get_helm.sh
    rm /tmp/get_helm.sh
    echo -e "${GREEN}✅ Helm installiert!${NC}"
else
    echo -e "${GREEN}✅ Helm bereits installiert!${NC}"
fi

# SSH-Schlüssel für root erstellen (falls nicht vorhanden)
echo -e "${YELLOW}🔑 Prüfe SSH-Schlüssel für root...${NC}"
if [ ! -f /root/.ssh/id_rsa ]; then
    echo -e "${YELLOW}Erstelle SSH-Schlüssel für root...${NC}"
    mkdir -p /root/.ssh
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -C "root@$(hostname)"
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/id_rsa
    chmod 644 /root/.ssh/id_rsa.pub
    echo -e "${GREEN}✅ SSH-Schlüssel für root erstellt!${NC}"
    echo
    echo -e "${BLUE}📋 Root SSH-Schlüssel (kopiere ihn für Terraform!):${NC}"
    echo "================================================"
    cat /root/.ssh/id_rsa.pub
    echo "================================================"
    echo
else
    echo -e "${GREEN}✅ SSH-Schlüssel bereits vorhanden!${NC}"
fi

# Proxmox-spezifische Verzeichnisse erstellen
echo -e "${YELLOW}📁 Erstelle Proxmox-Verzeichnisse...${NC}"
mkdir -p /root/spark-infra-backup
mkdir -p /etc/pve/spark-templates
mkdir -p /var/lib/vz/spark-isos

# Cloud-init Template vorbereiten
echo -e "${YELLOW}☁️  Bereite Cloud-init Template vor...${NC}"
if [ ! -f /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img ]; then
    echo "Lade Ubuntu 22.04 Cloud Image herunter..."
    wget https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img -O /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img
    echo -e "${GREEN}✅ Ubuntu Cloud Image heruntergeladen!${NC}"
else
    echo -e "${GREEN}✅ Ubuntu Cloud Image bereits vorhanden!${NC}"
fi

echo
echo -e "${GREEN}🎉 Proxmox Setup für Spark Infrastructure abgeschlossen!${NC}"
echo
echo -e "${BLUE}📋 Proxmox-spezifische Hinweise:${NC}"
echo "• Cloud-init Template wurde heruntergeladen"
echo "• SSH-Schlüssel für root wurde erstellt"
echo "• Alle Tools sind system-wide installiert"
echo "• Proxmox-Ansible-Module sind verfügbar"
echo
echo "Nächste Schritte:"
echo "1. Erstelle VM-Template in Proxmox Web-UI"
echo "2. Lade das spark-infra Projekt herunter"
echo "3. Folge der EINFACH-STARTEN.md Anleitung"
echo "4. Oder führe ./hack/deploy.sh aus"
echo
echo -e "${YELLOW}📝 VM-Template erstellen:${NC}"
echo "1. Proxmox Web-UI öffnen"
echo "2. VM erstellen mit ID 9000"
echo "3. Ubuntu Cloud Image als Disk verwenden"
echo "4. Cloud-init aktivieren"
echo "5. Als Template konvertieren"
echo
echo "Installierte Versionen:"
terraform --version | head -1
ansible --version | head -1
kubectl version --client --short 2>/dev/null || echo "kubectl: $(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | cut -d '"' -f 4 2>/dev/null || echo 'Version check failed')"
helm version --short 2>/dev/null || echo "helm: $(helm version --template='{{.Version}}' 2>/dev/null || echo 'Version check failed')"
echo
echo -e "${BLUE}Viel Spaß mit deiner Spark Infrastructure auf Proxmox! 🚀${NC}"
