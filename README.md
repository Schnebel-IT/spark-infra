# sit-spark Infrastructure Repository

Vollautomatisierte Infrastructure-as-Code Lösung für die Bereitstellung eines Kubernetes Clusters auf Proxmox VE 9.

## Überblick

Dieses Repository stellt eine komplette Automatisierungslösung bereit, um:
- 4 VMs auf Proxmox VE 9 zu erstellen (1 Manager, 3 Nodes)
- Kubernetes Cluster automatisch zu installieren und zu konfigurieren
- Helm und nginx-ingress-controller zu deployen
- NextJS Apps und REST APIs bereitzustellen

## Architektur

- **Manager Node**: VM-ID 2000, IP 10.10.1.1
- **Worker Nodes**: VM-IDs 2001-2003, IPs 10.10.1.10-12
- **Netzwerk**: vmbr2 (10.10.0.0/16) mit Gateway 10.10.0.1
- **OS**: Ubuntu 24.04 LTS

## Voraussetzungen

### Software
- Terraform >= 1.0
- Ansible >= 2.9
- SSH-Zugang zu Proxmox VE 9
- Bash Shell

### Proxmox Vorbereitung
- Proxmox VE 9 installiert und konfiguriert
- Ubuntu 24.04 LTS Cloud-Init Template erstellt
- Netzwerk vmbr2 konfiguriert
- API-Benutzer mit entsprechenden Berechtigungen

## Schnellstart

### 1. Repository klonen
\`\`\`bash
git clone <repository-url>
cd sit-spark-infrastructure
\`\`\`

### 2. Konfiguration
\`\`\`bash
# Terraform Konfiguration kopieren und anpassen
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Bearbeiten Sie terraform/terraform.tfvars mit Ihren Proxmox-Details
\`\`\`

### 3. Deployment
\`\`\`bash
# Vollständiges Deployment ausführen
./scripts/deploy.sh
\`\`\`

### 4. Validierung
\`\`\`bash
# Cluster-Status überprüfen
./scripts/validate.sh
\`\`\`

## Verzeichnisstruktur

\`\`\`
├── terraform/          # Terraform Konfiguration für VM-Bereitstellung
├── ansible/            # Ansible Playbooks für Kubernetes-Setup
│   ├── inventory/      # Ansible Inventories
│   ├── playbooks/      # Kubernetes Installation Playbooks
│   └── group_vars/     # Ansible Variablen
├── scripts/            # Orchestrierungs- und Deployment-Scripts
├── manifests/          # Kubernetes Manifests und Beispiele
└── docs/              # Zusätzliche Dokumentation
\`\`\`

## Konfiguration

### Terraform Variablen
Bearbeiten Sie `terraform/terraform.tfvars`:
- Proxmox API-Details
- VM-Konfiguration (IDs, IPs, Ressourcen)
- SSH-Schlüssel

### Ansible Variablen
Konfiguration in `ansible/group_vars/all.yml`:
- Kubernetes-Version
- Netzwerk-Einstellungen
- Zusätzliche Pakete

## Verwendung

### Anwendungen deployen
\`\`\`bash
# NextJS App deployen
kubectl apply -f manifests/examples/nextjs-app/

# REST API deployen
kubectl apply -f manifests/examples/rest-api/
\`\`\`

### Cluster verwalten
\`\`\`bash
# Cluster-Status
kubectl get nodes

# Pods anzeigen
kubectl get pods --all-namespaces

# Ingress-Status
kubectl get ingress
\`\`\`

## Troubleshooting

### Häufige Probleme
1. **VM-Erstellung fehlgeschlagen**: Überprüfen Sie Proxmox-Berechtigungen und Template
2. **Kubernetes-Installation fehlgeschlagen**: Prüfen Sie Netzwerk-Konnektivität zwischen VMs
3. **Ingress nicht erreichbar**: Überprüfen Sie Firewall-Regeln und DNS-Konfiguration

### Logs
\`\`\`bash
# Terraform Logs
terraform plan -detailed-exitcode

# Ansible Logs
ansible-playbook -vvv ansible/site.yml

# Kubernetes Logs
kubectl logs -n kube-system <pod-name>
\`\`\`

## Cleanup

\`\`\`bash
# Komplette Infrastruktur entfernen
./scripts/destroy.sh
\`\`\`

## Beitragen

1. Fork des Repositories
2. Feature Branch erstellen
3. Änderungen committen
4. Pull Request erstellen

## Lizenz

[Lizenz hier einfügen]

## Support

Bei Fragen oder Problemen:
- Issues im Repository erstellen
- Dokumentation in `docs/` konsultieren
- Schnebel-IT Team kontaktieren