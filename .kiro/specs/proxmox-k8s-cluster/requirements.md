# Requirements Document

## Introduction

Das sit-spark Infrastructure Repository soll eine vollautomatisierte Lösung für die Bereitstellung eines Kubernetes Clusters auf Proxmox VE 9 bieten. Das System soll 4 VMs (1 Manager, 3 Nodes) erstellen, Kubernetes installieren und konfigurieren sowie zusätzliche Tools wie Helm und nginx-ingress-controller bereitstellen. Dies ermöglicht es Schnebel-IT, interne und externe Anwendungen (NextJS Apps, REST APIs) effizient in der Cloud zu deployen.

## Requirements

### Requirement 1

**User Story:** Als DevOps Engineer möchte ich automatisiert Proxmox VMs für ein Kubernetes Cluster erstellen, damit ich nicht manuell VMs konfigurieren muss.

#### Acceptance Criteria

1. WHEN das Infrastructure Script ausgeführt wird THEN soll das System 4 VMs auf Proxmox VE 9 erstellen
2. WHEN VMs erstellt werden THEN soll der Manager die VM-ID 2000 und IP 10.10.1.1 erhalten
3. WHEN VMs erstellt werden THEN sollen die 3 Nodes die VM-IDs 2001, 2002, 2003 und IPs 10.10.1.10, 10.10.1.11, 10.10.1.12 erhalten
4. WHEN VMs erstellt werden THEN sollen alle VMs das Netzwerk vmbr2 (10.10.0.0/16) mit Gateway 10.10.0.1 verwenden
5. WHEN VMs erstellt werden THEN sollen alle VMs mit einem geeigneten Linux OS (Ubuntu/Debian) bereitgestellt werden

### Requirement 2

**User Story:** Als DevOps Engineer möchte ich Kubernetes automatisch auf den erstellten VMs installieren, damit ich sofort einen funktionsfähigen Cluster habe.

#### Acceptance Criteria

1. WHEN VMs bereit sind THEN soll das System Kubernetes auf allen VMs installieren
2. WHEN Kubernetes installiert ist THEN soll der Manager als Control Plane konfiguriert werden
3. WHEN Control Plane bereit ist THEN sollen die 3 Nodes dem Cluster beitreten
4. WHEN Cluster initialisiert ist THEN soll das System die Cluster-Konnektivität validieren
5. WHEN Installation abgeschlossen ist THEN soll kubectl auf dem Manager konfiguriert sein

### Requirement 3

**User Story:** Als DevOps Engineer möchte ich Helm und nginx-ingress-controller automatisch installiert haben, damit ich sofort Anwendungen deployen kann.

#### Acceptance Criteria

1. WHEN Kubernetes Cluster bereit ist THEN soll Helm auf dem Manager installiert werden
2. WHEN Helm installiert ist THEN soll nginx-ingress-controller über Helm deployed werden
3. WHEN nginx-ingress-controller deployed ist THEN soll er für externe Zugriffe konfiguriert sein
4. WHEN Installation abgeschlossen ist THEN soll das System die Ingress-Funktionalität validieren

### Requirement 4

**User Story:** Als DevOps Engineer möchte ich eine wiederverwendbare und versionierte Infrastructure-as-Code Lösung, damit ich das Setup reproduzieren und verwalten kann.

#### Acceptance Criteria

1. WHEN das Repository erstellt wird THEN soll es Terraform/Ansible/Scripts für die Automatisierung enthalten
2. WHEN das Setup ausgeführt wird THEN soll es idempotent sein (mehrfache Ausführung sicher)
3. WHEN Fehler auftreten THEN soll das System aussagekräftige Fehlermeldungen liefern
4. WHEN das Setup abgeschlossen ist THEN soll eine Dokumentation für die Nutzung verfügbar sein
5. WHEN das System läuft THEN soll es Monitoring/Health-Checks für den Cluster bereitstellen

### Requirement 5

**User Story:** Als Entwickler möchte ich einfach NextJS Apps und REST APIs auf dem Cluster deployen können, damit ich die sit-spark Cloud-Infrastruktur nutzen kann.

#### Acceptance Criteria

1. WHEN der Cluster bereit ist THEN soll er für die Bereitstellung von NextJS Anwendungen konfiguriert sein
2. WHEN der Cluster bereit ist THEN soll er für die Bereitstellung von REST APIs konfiguriert sein
3. WHEN Anwendungen deployed werden THEN sollen sie über nginx-ingress extern erreichbar sein
4. WHEN das Repository bereitgestellt wird THEN soll es Beispiel-Deployments für NextJS und REST APIs enthalten