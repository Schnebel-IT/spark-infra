# Spark Infrastructure - Schnebel-IT

Eine skalierbare Infrastruktur-Plattform für SAAS-Entwicklung und REST-APIs mit hoher Verfügbarkeit.

## Übersicht

Spark ist eine Kubernetes-basierte Plattform, die auf Proxmox VMs läuft und für hohe Verfügbarkeit und Skalierbarkeit entwickelt wurde. Die Infrastruktur kann von einem einzelnen Host auf mehrere Hosts erweitert werden.

## Architektur

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Host(s)                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Master    │  │   Worker    │  │   Worker    │   ...   │
│  │   Node 1    │  │   Node 1    │  │   Node 2    │         │
│  │             │  │             │  │             │         │
│  │ Kubernetes  │  │ Kubernetes  │  │ Kubernetes  │         │
│  │   Control   │  │    Node     │  │    Node     │         │
│  │   Plane     │  │             │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Komponenten

### Core Infrastructure

- **Proxmox VE**: Hypervisor für VM-Management
- **Terraform**: Infrastructure as Code - VM-Provisionierung
- **Ansible**: Configuration Management - Software-Installation und Konfiguration
- **Kubernetes**: Container-Orchestrierung

### Terraform vs. Ansible - Aufgabenteilung

**Terraform** ist zuständig für:

- ✅ Erstellen und Verwalten von VMs in Proxmox
- ✅ Netzwerk-Konfiguration (IP-Adressen, VLANs)
- ✅ Storage-Zuweisung (Disks, Volumes)
- ✅ VM-Ressourcen (CPU, RAM, Disk-Größe)
- ✅ Infrastructure State Management
- ✅ VM-Lifecycle (Create, Update, Destroy)

**Ansible** ist zuständig für:

- ✅ Betriebssystem-Konfiguration
- ✅ Software-Installation (Docker, Kubernetes, etc.)
- ✅ Service-Konfiguration und -Management
- ✅ Security-Hardening (Firewall, SSH, etc.)
- ✅ Application Deployment
- ✅ Configuration Drift Management

**Warum beide Tools?**

- **Terraform**: "Was soll existieren?" (Deklarativ für Infrastruktur)
- **Ansible**: "Wie soll es konfiguriert sein?" (Prozedural für Konfiguration)

### Monitoring & Observability

- **Prometheus**: Metriken-Sammlung
- **Grafana**: Dashboards und Visualisierung
- **ELK Stack**: Logging (Elasticsearch, Logstash, Kibana)
- **AlertManager**: Benachrichtigungen

### Development Platform

- **GitLab/Jenkins**: CI/CD Pipeline
- **Docker Registry**: Container Images
- **Ingress Controller**: Load Balancing und SSL
- **Cert-Manager**: Automatische SSL-Zertifikate

## Verzeichnisstruktur

```
spark-infra/
├── ansible/                 # Ansible Playbooks und Rollen
│   ├── playbooks/          # Hauptplaybooks
│   ├── roles/              # Wiederverwendbare Rollen
│   ├── inventory/          # Host-Inventare
│   └── group_vars/         # Gruppenvariablen
├── terraform/              # Infrastructure as Code
│   ├── proxmox/           # Proxmox VM Definitionen
│   └── modules/           # Wiederverwendbare Module
├── kubernetes/             # K8s Manifeste und Helm Charts
│   ├── manifests/         # YAML Manifeste
│   ├── helm-charts/       # Helm Charts
│   └── operators/         # Kubernetes Operators
├── monitoring/             # Monitoring Stack
│   ├── prometheus/        # Prometheus Konfiguration
│   ├── grafana/           # Grafana Dashboards
│   └── elk/               # ELK Stack Setup
├── scripts/               # Utility Scripts
└── docs/                  # Dokumentation
```

## 🚀 Schnellstart für Anfänger

**Für alle die es EINFACH wollen:**

```bash
# 1. System vorbereiten
curl -sSL https://raw.githubusercontent.com/schnebel-it/spark-infra/main/scripts/quick-setup.sh | bash

# 2. Projekt herunterladen
git clone <REPOSITORY-URL> spark-infra
cd spark-infra

# 3. ALLES AUTOMATISCH DEPLOYEN
./scripts/deploy.sh
```

**Das war's! 🎉**

➡️ **Detaillierte Anleitung:** [EINFACH-STARTEN.md](EINFACH-STARTEN.md)

## 🏗️ Spark-Infrastruktur Übersicht

### Server-Architektur

| Server-Name           | Rolle              | IP            | Funktion             | Ressourcen            |
| --------------------- | ------------------ | ------------- | -------------------- | --------------------- |
| **spark-hypervisor**  | Proxmox Host       | 192.168.1.100 | VM-Management        | Physical Server       |
| **spark-conductor**   | Kubernetes Master  | 192.168.1.101 | Cluster-Controller   | 2 CPU, 4GB RAM, 50GB  |
| **spark-executor-01** | Kubernetes Worker  | 192.168.1.102 | Container-Ausführung | 4 CPU, 8GB RAM, 100GB |
| **spark-executor-02** | Kubernetes Worker  | 192.168.1.103 | Container-Ausführung | 4 CPU, 8GB RAM, 100GB |
| **spark-observer**    | Monitoring         | 192.168.1.110 | Prometheus/Grafana   | 2 CPU, 4GB RAM, 100GB |
| **spark-logger**      | Logging            | 192.168.1.111 | ELK Stack            | 2 CPU, 4GB RAM, 100GB |
| **spark-builder**     | CI/CD              | 192.168.1.120 | GitHub Runner        | 2 CPU, 4GB RAM, 50GB  |
| **spark-registry**    | Container Registry | 192.168.1.121 | Docker Images        | 2 CPU, 4GB RAM, 50GB  |

### Netzwerk-Segmentierung

#### 🌍 Öffentliche Services (Internet-zugänglich)

- **Load Balancer IP**: 192.168.1.200-210
- **SSL-Zertifikate**: Let's Encrypt (automatisch)
- **Ingress Controller**: nginx-public
- **Anwendungen**: SAAS-Produkte für Kunden

#### 🏢 Interne Services (VPN-Zugang)

- **Load Balancer IP**: 192.168.1.201-205
- **SSL-Zertifikate**: Schnebel-IT CA (selbst-signiert)
- **Ingress Controller**: nginx-internal
- **Anwendungen**: Interne Tools und APIs
- **Zugriff**: Nur über VPN-Tunnel

### Service-Ports

| Service         | Port | Zugriff | Beschreibung          |
| --------------- | ---- | ------- | --------------------- |
| Grafana         | 3000 | Intern  | Monitoring Dashboard  |
| Prometheus      | 9090 | Intern  | Metriken-Sammlung     |
| Kibana          | 5601 | Intern  | Log-Analyse           |
| Docker Registry | 5000 | Intern  | Container Images      |
| Kubernetes API  | 6443 | Intern  | Cluster-Management    |
| SSH             | 22   | Intern  | Server-Administration |

### Storage-Übersicht

| Typ               | Größe | Verwendung         | Mount Point          |
| ----------------- | ----- | ------------------ | -------------------- |
| System            | 50GB  | OS + Software      | /                    |
| Container Storage | 100GB | Docker Images      | /var/lib/docker      |
| Monitoring Data   | 50GB  | Prometheus/Grafana | /mnt/monitoring-data |
| Log Storage       | 100GB | Elasticsearch      | /mnt/logging-data    |
| Registry Storage  | 50GB  | Docker Registry    | /mnt/registry-data   |

### Backup-Strategie

| Komponente       | Häufigkeit   | Retention  | Methode                   |
| ---------------- | ------------ | ---------- | ------------------------- |
| VM Snapshots     | Täglich      | 7 Tage     | Proxmox Backup            |
| Kubernetes ETCD  | 6h           | 30 Tage    | Velero                    |
| Monitoring Data  | Täglich      | 30 Tage    | Prometheus Remote Storage |
| Application Data | Täglich      | 90 Tage    | PVC Snapshots             |
| Configuration    | Bei Änderung | Unbegrenzt | Git Repository            |

### Security-Features

#### 🛡️ Netzwerk-Sicherheit

- **Network Policies**: Kubernetes-native Segmentierung
- **Firewall**: UFW auf allen VMs
- **VPN-Integration**: WireGuard/OpenVPN für interne Services
- **SSL/TLS**: Automatische Zertifikate für alle Services

#### 🔐 Authentifizierung

- **SSH**: Nur Key-basiert, Passwort deaktiviert
- **Kubernetes RBAC**: Rollenbasierte Zugriffskontrolle
- **Service Accounts**: Separate Accounts für Services
- **Secrets Management**: Kubernetes Secrets + Ansible Vault

#### 📊 Monitoring & Alerting

- **Uptime Monitoring**: 99.9% SLA-Tracking
- **Performance Metrics**: CPU, RAM, Disk, Network
- **Application Metrics**: Custom Business Metrics
- **Alerting**: E-Mail, Slack, PagerDuty Integration

### Skalierungs-Roadmap

#### Phase 1: Single-Host (Aktuell)

- 1x Proxmox Host
- 8x VMs
- Kapazität: ~20 kleine Apps

#### Phase 2: Multi-Host (Erweiterung)

- 3x Proxmox Hosts
- 24x VMs (HA-Setup)
- Kapazität: ~100 Apps

#### Phase 3: Hybrid-Cloud

- On-Premise + Cloud
- Multi-Region Setup
- Kapazität: Unbegrenzt

### 📊 Kapazitäts-Planung

#### Aktuelle Konfiguration (Single-Host)

- **Gesamt-Ressourcen**: ~16 CPU Cores, ~32GB RAM, ~600GB Storage
- **Geschätzte App-Kapazität**: 15-25 kleine bis mittlere Anwendungen
- **Concurrent Users**: ~1,000-5,000 je nach App-Typ
- **Durchsatz**: ~10,000 Requests/Minute

#### Performance-Benchmarks

| Metrik        | Zielwert | Aktuell | Monitoring    |
| ------------- | -------- | ------- | ------------- |
| Uptime        | >99.9%   | -       | Grafana       |
| Response Time | <200ms   | -       | Prometheus    |
| CPU Usage     | <70%     | -       | Node Exporter |
| Memory Usage  | <80%     | -       | cAdvisor      |
| Disk I/O      | <80%     | -       | Grafana       |

### 🔄 CI/CD Pipeline

#### GitHub Actions Workflow

1. **Code Push** → GitHub Repository
2. **Build** → Docker Image auf spark-builder
3. **Test** → Automatische Tests
4. **Deploy** → Kubernetes Cluster
5. **Monitor** → Grafana/Prometheus Alerts

#### Deployment-Strategien

- **Blue-Green**: Zero-Downtime für kritische Apps
- **Rolling Updates**: Standard für normale Apps
- **Canary**: A/B Testing für neue Features

### 🎯 Schnebel-IT Spezifikationen

#### Für SAAS-Produkte

- **Öffentlicher Zugang**: Über nginx-public Ingress
- **SSL-Zertifikate**: Let's Encrypt (automatisch erneuert)
- **Monitoring**: 24/7 Uptime-Überwachung
- **Backup**: Tägliche Snapshots mit 30-Tage Retention

#### Für interne APIs

- **VPN-Zugang**: Nur über sicheren Tunnel
- **Interne Zertifikate**: Schnebel-IT CA
- **Entwickler-Tools**: Direkter kubectl-Zugang
- **Staging-Umgebung**: Separate Namespaces

### 🚨 Disaster Recovery

#### RTO/RPO Ziele

- **Recovery Time Objective (RTO)**: <4 Stunden
- **Recovery Point Objective (RPO)**: <1 Stunde
- **Backup-Frequenz**: Täglich (automatisch)
- **Test-Frequenz**: Monatlich

#### Notfall-Prozeduren

1. **VM-Ausfall**: Automatisches Failover zu anderen Nodes
2. **Host-Ausfall**: Manuelle Wiederherstellung von Backups
3. **Komplett-Ausfall**: Rebuild von Infrastructure-Code
4. **Daten-Verlust**: Restore von letztem Backup

## Manueller Deployment-Workflow

### 1. Infrastruktur bereitstellen (Terraform)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars anpassen (Proxmox-Zugangsdaten, etc.)
terraform init
terraform plan
terraform apply
```

### 2. VMs konfigurieren (Ansible)

```bash
cd ansible
# Vault-Passwort setzen
echo "your-vault-password" > .vault_pass
ansible-vault edit group_vars/vault.yml  # Passwörter setzen
ansible-playbook --vault-password-file .vault_pass playbooks/site.yml
```

### 3. Kubernetes-Manifeste deployen

```bash
kubectl apply -f kubernetes/manifests/
kubectl apply -f monitoring/
```

## Typischer Workflow

1. **Neue VMs hinzufügen**: `./scripts/deploy.sh terraform`
2. **Software aktualisieren**: `./scripts/deploy.sh ansible`
3. **Apps deployen**: GitHub Actions (automatisch)
4. **Status prüfen**: `./scripts/deploy.sh status`

## Anforderungen

- Proxmox VE 8.x
- Ansible 2.9+
- Terraform 1.0+
- kubectl 1.28+

## Lizenz

Proprietär - Schnebel-IT
