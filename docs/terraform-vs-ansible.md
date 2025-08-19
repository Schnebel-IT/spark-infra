# Terraform vs. Ansible in der Spark-Infrastruktur

## Übersicht

Die Spark-Infrastruktur verwendet beide Tools in einer komplementären Weise:

- **Terraform** = Infrastructure as Code (IaC)
- **Ansible** = Configuration Management

## Detaillierte Aufgabenteilung

### Terraform Verantwortlichkeiten

#### 1. VM-Lifecycle Management

```hcl
# Beispiel: VM erstellen
resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-01"
  cores       = 2
  memory      = 4096
  disk_size   = "50G"
  # ...
}
```

**Was Terraform macht:**

- VMs erstellen, ändern, löschen
- VM-Ressourcen verwalten (CPU, RAM, Disk)
- IP-Adressen zuweisen
- Storage-Volumes erstellen
- Netzwerk-Bridges konfigurieren

**Was Terraform NICHT macht:**

- Software installieren
- Services konfigurieren
- Betriebssystem-Einstellungen

#### 2. State Management

Terraform verwaltet den aktuellen Zustand der Infrastruktur:

```bash
terraform plan   # Was wird geändert?
terraform apply  # Änderungen anwenden
terraform destroy # Infrastruktur entfernen
```

### Ansible Verantwortlichkeiten

#### 1. Software-Installation

```yaml
# Beispiel: Docker installieren
- name: Install Docker
  package:
    name: docker-ce
    state: present
```

**Was Ansible macht:**

- Pakete installieren/aktualisieren
- Services starten/stoppen
- Konfigurationsdateien erstellen
- Benutzer und Berechtigungen verwalten
- Security-Hardening

**Was Ansible NICHT macht:**

- VMs erstellen/löschen
- Hardware-Ressourcen ändern
- Infrastruktur-Lifecycle

#### 2. Configuration Drift Management

Ansible stellt sicher, dass die Konfiguration konsistent bleibt:

```bash
ansible-playbook site.yml  # Konfiguration anwenden
```

## Workflow-Beispiele

### Neue VM hinzufügen

1. **Terraform**: VM-Definition erweitern

```hcl
variable "k8s_worker_count" {
  default = 3  # Von 2 auf 3 erhöht
}
```

2. **Terraform**: Infrastruktur anwenden

```bash
terraform plan
terraform apply
```

3. **Ansible**: Neue VM konfigurieren

```bash
ansible-playbook playbooks/site.yml
```

### Software aktualisieren

1. **Ansible**: Playbook anpassen

```yaml
kubernetes:
  version: "1.29.0" # Version aktualisiert
```

2. **Ansible**: Konfiguration anwenden

```bash
ansible-playbook playbooks/kubernetes-cluster.yml
```

### VM-Ressourcen ändern

1. **Terraform**: Ressourcen anpassen

```hcl
k8s_worker_memory = 16384  # Von 8192 auf 16384 MB
```

2. **Terraform**: Änderung anwenden

```bash
terraform apply
```

## Vorteile dieser Aufteilung

### 1. Separation of Concerns

- **Terraform**: Hardware/Infrastruktur
- **Ansible**: Software/Konfiguration

### 2. Expertise-Trennung

- **Infrastructure Engineers**: Terraform
- **System Administrators**: Ansible
- **Developers**: Kubernetes/Apps

### 3. Unterschiedliche Zyklen

- **Terraform**: Selten (Infrastruktur-Änderungen)
- **Ansible**: Häufig (Updates, Patches)
- **Kubernetes**: Sehr häufig (App-Deployments)

### 4. Rollback-Strategien

- **Terraform**: Infrastructure State Rollback
- **Ansible**: Configuration Rollback
- **Kubernetes**: Application Rollback

## Best Practices

### 1. Terraform

```bash
# Immer erst planen
terraform plan

# State-Backups verwenden
terraform init -backend-config="backup=true"

# Module für Wiederverwendbarkeit
module "vm" {
  source = "./modules/vm"
}
```

### 2. Ansible

```bash
# Dry-run vor Produktions-Deployment
ansible-playbook --check site.yml

# Vault für Secrets
ansible-vault encrypt group_vars/vault.yml

# Tags für selektive Ausführung
ansible-playbook site.yml --tags "docker,kubernetes"
```

### 3. Integration

```bash
# 1. Infrastruktur
cd terraform && terraform apply

# 2. Konfiguration (nach Terraform)
cd ansible && ansible-playbook site.yml

# 3. Applications (nach Ansible)
kubectl apply -f kubernetes/manifests/
```

## Troubleshooting

### Terraform-Probleme

```bash
# State prüfen
terraform show

# State reparieren
terraform refresh

# Resource importieren
terraform import proxmox_vm_qemu.vm 100
```

### Ansible-Probleme

```bash
# Connectivity testen
ansible all -m ping

# Einzelne Tasks debuggen
ansible-playbook site.yml --start-at-task "Install Docker"

# Verbose Output
ansible-playbook -vvv site.yml
```

## Fazit

Die Kombination aus Terraform und Ansible bietet:

- **Klarheit**: Jedes Tool für seine Stärken
- **Flexibilität**: Unabhängige Entwicklung und Deployment
- **Skalierbarkeit**: Von 1 auf N Hosts erweiterbar
- **Wartbarkeit**: Saubere Trennung der Verantwortlichkeiten

Diese Architektur ermöglicht es Schnebel-IT, sowohl die Infrastruktur als auch die Anwendungen effizient zu verwalten und zu skalieren.
