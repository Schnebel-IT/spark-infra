# 🚀 Spark-Infrastruktur - Einfach Starten

**Für Anfänger ohne Terraform/Ansible Erfahrung**

## 📋 Was du brauchst

1. **Einen Computer mit Linux** (Ubuntu empfohlen)
2. **Proxmox Server** mit Internet-Zugang
3. **30 Minuten Zeit**
4. **Diese Anleitung** 😊

## 🎯 Was passiert?

Wir bauen eine komplette Infrastruktur mit diesen "Spark"-Servern:

- **spark-hypervisor** = Dein Proxmox Host
- **spark-conductor** = Kubernetes Master (der Chef)
- **spark-executor-01/02** = Kubernetes Worker (die Arbeiter)
- **spark-observer** = Monitoring (der Wächter)
- **spark-logger** = Logging (der Protokollant)
- **spark-builder** = CI/CD (der Baumeister)
- **spark-registry** = Container Registry (das Lager)

---

## 🛠️ Schritt 1: Computer vorbereiten

**Kopiere und füge diese Befehle ein:**

```bash
# System updaten
sudo apt update && sudo apt upgrade -y

# Benötigte Software installieren
sudo apt install -y curl wget git python3 python3-pip

# Terraform installieren
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
sudo unzip terraform_1.6.0_linux_amd64.zip -d /usr/local/bin/
rm terraform_1.6.0_linux_amd64.zip

# Ansible installieren
pip3 install ansible

# Kubectl installieren
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

echo "✅ Alles installiert!"
```

---

## 🔑 Schritt 2: SSH-Schlüssel erstellen

**Wenn du noch keinen SSH-Schlüssel hast:**

```bash
# SSH-Schlüssel erstellen (einfach Enter drücken bei allen Fragen)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Öffentlichen Schlüssel anzeigen (kopiere den Inhalt!)
cat ~/.ssh/id_rsa.pub
```

**💡 Tipp:** Kopiere den kompletten Inhalt - brauchst du gleich!

---

## 📁 Schritt 3: Projekt herunterladen

```bash
# In dein Home-Verzeichnis wechseln
cd ~

# Projekt klonen (oder ZIP herunterladen)
git clone <DEIN-REPOSITORY-URL> spark-infra
cd spark-infra

echo "✅ Projekt bereit!"
```

---

## ⚙️ Schritt 4: Konfiguration anpassen

### 4.1 Terraform konfigurieren

```bash
cd terraform

# Beispiel-Konfiguration kopieren
cp terraform.tfvars.example terraform.tfvars

# Datei bearbeiten
nano terraform.tfvars
```

**Ändere diese Werte in der Datei:**

```hcl
# DEINE Proxmox-Daten eingeben:
proxmox_api_url = "https://DEINE-PROXMOX-IP:8006/api2/json"
proxmox_password = "DEIN-PROXMOX-PASSWORT"
proxmox_node = "spark-hypervisor"  # Oder dein Proxmox Node-Name

# DEIN Netzwerk anpassen:
network_prefix = "192.168.1"      # Dein Netzwerk (erste 3 Zahlen)
network_gateway = "192.168.1.1"   # Dein Router

# DEINEN SSH-Schlüssel einfügen (von Schritt 2):
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E... HIER-DEINEN-SCHLÜSSEL"
```

**💾 Speichern:** `Ctrl+X`, dann `Y`, dann `Enter`

### 4.2 Ansible konfigurieren

```bash
cd ../ansible

# Passwörter setzen
echo "mein-sicheres-passwort" > .vault_pass
ansible-vault create group_vars/vault.yml --vault-password-file .vault_pass
```

**In der Datei eingeben:**

```yaml
vault_grafana_password: "admin123"
vault_github_runner_token: "DEIN-GITHUB-TOKEN"
vault_registry_password: "registry123"
vault_elasticsearch_password: "elastic123"
vault_proxmox_password: "DEIN-PROXMOX-PASSWORT"
```

**💾 Speichern:** `Ctrl+X`, dann `Y`, dann `Enter`

---

## 🚀 Schritt 5: ALLES AUTOMATISCH DEPLOYEN!

### 5.1 VMs erstellen (Terraform)

```bash
cd ~/spark-infra/terraform

# Terraform initialisieren
terraform init

# Plan anzeigen (was passiert?)
terraform plan

# 🎯 ALLES ERSTELLEN (dauert 5-10 Minuten)
terraform apply
```

**Wenn gefragt:** Tippe `yes` und drücke Enter

### 5.2 VMs konfigurieren (Ansible)

```bash
cd ~/spark-infra/ansible

# Warten bis VMs bereit sind (2-3 Minuten)
sleep 180

# 🎯 ALLES KONFIGURIEREN (dauert 10-20 Minuten)
ansible-playbook --vault-password-file .vault_pass playbooks/site.yml
```

### 5.3 Kubernetes starten

```bash
cd ~/spark-infra

# Kubeconfig kopieren
mkdir -p ~/.kube
cp ansible/files/admin.conf ~/.kube/config

# 🎯 KUBERNETES DEPLOYEN
kubectl apply -f kubernetes/manifests/
kubectl apply -f monitoring/
```

---

## 🎉 Schritt 6: Überprüfen ob alles läuft

```bash
# Alle Nodes anzeigen
kubectl get nodes -o wide

# Alle Pods anzeigen
kubectl get pods -A

# Services anzeigen
kubectl get svc -A
```

**Du solltest sehen:**

- ✅ Alle Nodes "Ready"
- ✅ Alle Pods "Running"
- ✅ Services mit IP-Adressen

---

## 🌐 Schritt 7: Zugriff auf Services

### Grafana (Monitoring)

- **URL:** `http://192.168.1.200:3000`
- **Login:** admin / admin123

### Kubernetes Dashboard

```bash
# Dashboard installieren
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Token erstellen
kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa
kubectl create token dashboard-admin-sa
```

### Docker Registry

- **URL:** `http://192.168.1.201:5000`

---

## 🆘 Hilfe! Etwas funktioniert nicht!

### Häufige Probleme:

**"Connection refused" Fehler:**

```bash
# Warten und nochmal versuchen
sleep 60
ansible-playbook --vault-password-file .vault_pass playbooks/site.yml
```

**"No such host" Fehler:**

```bash
# IPs in /etc/hosts eintragen
sudo nano /etc/hosts

# Hinzufügen:
192.168.1.101 spark-conductor
192.168.1.102 spark-executor-01
192.168.1.103 spark-executor-02
```

**Pods starten nicht:**

```bash
# Beschreibung anzeigen
kubectl describe pod POD-NAME -n NAMESPACE

# Logs anzeigen
kubectl logs POD-NAME -n NAMESPACE
```

### Alles neu starten:

```bash
# Kubernetes zurücksetzen
kubectl delete -f kubernetes/manifests/
kubectl delete -f monitoring/

# VMs löschen
cd terraform
terraform destroy

# Neu beginnen bei Schritt 5
```

---

## 🎯 Fertig! Was nun?

### Apps deployen:

1. Code in GitHub pushen
2. GitHub Actions läuft automatisch
3. App wird deployed

### Monitoring schauen:

- Grafana: `http://192.168.1.200:3000`

### Logs schauen:

- Kibana: `http://192.168.1.201:5601`

---

## 📚 Mehr lernen?

- **Kubernetes:** https://kubernetes.io/docs/tutorials/
- **Terraform:** https://learn.hashicorp.com/terraform
- **Ansible:** https://docs.ansible.com/ansible/latest/user_guide/

---

**🎉 Herzlichen Glückwunsch! Du hast eine komplette Cloud-Infrastruktur aufgebaut!**

_Bei Fragen: Einfach in die `docs/` schauen oder fragen! 😊_
