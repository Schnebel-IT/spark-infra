#!/bin/bash

# 🚀 Spark Infrastructure - Quick Setup für Anfänger
# Installiert automatisch alle benötigten Tools

set -e

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Spark Infrastructure - Quick Setup${NC}"
echo "====================================="
echo

# System updaten
echo -e "${YELLOW}📦 Aktualisiere System...${NC}"
sudo apt update && sudo apt upgrade -y

# Grundlegende Tools installieren
echo -e "${YELLOW}🛠️  Installiere grundlegende Tools...${NC}"
sudo apt install -y curl wget git python3 python3-pip unzip software-properties-common

# Terraform installieren
echo -e "${YELLOW}🏗️  Installiere Terraform...${NC}"
if ! command -v terraform &> /dev/null; then
    TERRAFORM_VERSION="1.6.0"
    wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    sudo unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -d /usr/local/bin/
    rm "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    echo -e "${GREEN}✅ Terraform installiert!${NC}"
else
    echo -e "${GREEN}✅ Terraform bereits installiert!${NC}"
fi

# Ansible installieren
echo -e "${YELLOW}⚙️  Installiere Ansible...${NC}"
if ! command -v ansible &> /dev/null; then
    pip3 install --user ansible
    echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
    export PATH=$PATH:~/.local/bin
    echo -e "${GREEN}✅ Ansible installiert!${NC}"
else
    echo -e "${GREEN}✅ Ansible bereits installiert!${NC}"
fi

# kubectl installieren
echo -e "${YELLOW}☸️  Installiere kubectl...${NC}"
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo -e "${GREEN}✅ kubectl installiert!${NC}"
else
    echo -e "${GREEN}✅ kubectl bereits installiert!${NC}"
fi

# Helm installieren
echo -e "${YELLOW}🎯 Installiere Helm...${NC}"
if ! command -v helm &> /dev/null; then
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm
    echo -e "${GREEN}✅ Helm installiert!${NC}"
else
    echo -e "${GREEN}✅ Helm bereits installiert!${NC}"
fi

# SSH-Schlüssel erstellen (falls nicht vorhanden)
echo -e "${YELLOW}🔑 Prüfe SSH-Schlüssel...${NC}"
if [ ! -f ~/.ssh/id_rsa ]; then
    echo -e "${YELLOW}Erstelle SSH-Schlüssel...${NC}"
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo -e "${GREEN}✅ SSH-Schlüssel erstellt!${NC}"
    echo
    echo -e "${BLUE}📋 Dein öffentlicher SSH-Schlüssel (kopiere ihn!):${NC}"
    echo "================================================"
    cat ~/.ssh/id_rsa.pub
    echo "================================================"
    echo
else
    echo -e "${GREEN}✅ SSH-Schlüssel bereits vorhanden!${NC}"
fi

# Verzeichnisse erstellen
mkdir -p ~/spark-infra-backup

echo
echo -e "${GREEN}🎉 Setup abgeschlossen!${NC}"
echo
echo "Nächste Schritte:"
echo "1. Lade das spark-infra Projekt herunter"
echo "2. Folge der EINFACH-STARTEN.md Anleitung"
echo "3. Oder führe ./scripts/deploy.sh aus"
echo
echo "Installierte Versionen:"
terraform --version | head -1
ansible --version | head -1
kubectl version --client --short 2>/dev/null || echo "kubectl: $(kubectl version --client -o yaml | grep gitVersion | cut -d '"' -f 4)"
helm version --short 2>/dev/null || echo "helm: $(helm version --template='{{.Version}}')"
echo
echo -e "${BLUE}Viel Spaß mit deiner Spark Infrastructure! 🚀${NC}"
