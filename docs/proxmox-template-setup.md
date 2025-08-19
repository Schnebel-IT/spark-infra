# Proxmox VM-Template Setup für Spark Infrastructure

Diese Anleitung erklärt, wie Sie ein Ubuntu Cloud-init Template in Proxmox Community Edition erstellen, das für die Spark Infrastructure verwendet wird.

## Voraussetzungen

- Proxmox VE Community Edition installiert
- Root-Zugang zu Proxmox
- `quick-setup.sh` bereits ausgeführt

## Schritt 1: Cloud Image vorbereiten

Das Ubuntu Cloud Image wurde bereits durch `quick-setup.sh` heruntergeladen:

```bash
ls -la /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img
```

## Schritt 2: VM-Template erstellen

### Via Proxmox Web-UI

1. **Proxmox Web-UI öffnen**

   - Browser: `https://IHRE-PROXMOX-IP:8006`
   - Login mit root-Credentials

2. **Neue VM erstellen**
   - Klick auf "Create VM"
   - **General Tab:**
     - VM ID: `9000`
     - Name: `ubuntu-22.04-cloud-init`
3. **OS Tab:**
   - "Do not use any media" auswählen
4. **System Tab:**
   - Machine: `q35`
   - BIOS: `OVMF (UEFI)`
   - Add EFI Disk: ✅
   - Add TPM: ❌
   - SCSI Controller: `VirtIO SCSI single`
5. **Hard Disk Tab:**
   - Delete the default disk (we'll add the cloud image later)
6. **CPU Tab:**
   - Cores: `2`
   - Type: `host`
7. **Memory Tab:**
   - Memory: `2048` MB
8. **Network Tab:**
   - Bridge: `vmbr0`
   - Model: `VirtIO (paravirtualized)`

### Via Command Line

```bash
# VM erstellen
qm create 9000 \
  --name ubuntu-22.04-cloud-init \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci

# Cloud Image als Disk hinzufügen
qm importdisk 9000 /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img local-lvm

# Disk konfigurieren
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0

# Cloud-init Drive hinzufügen
qm set 9000 --ide2 local-lvm:cloudinit

# Boot-Reihenfolge setzen
qm set 9000 --boot c --bootdisk scsi0

# VGA auf serial setzen (für Cloud-init)
qm set 9000 --serial0 socket --vga serial0

# QEMU Guest Agent aktivieren
qm set 9000 --agent enabled=1
```

## Schritt 3: Cloud-init konfigurieren

```bash
# Cloud-init User setzen
qm set 9000 --ciuser ubuntu

# SSH-Schlüssel hinzufügen
qm set 9000 --sshkey /root/.ssh/id_rsa.pub

# IP-Konfiguration (DHCP)
qm set 9000 --ipconfig0 ip=dhcp
```

## Schritt 4: Template erstellen

```bash
# VM als Template konvertieren
qm template 9000
```

## Schritt 5: Template testen

```bash
# Test-VM vom Template erstellen
qm clone 9000 999 --name test-vm --full

# Test-VM starten
qm start 999

# Status prüfen
qm status 999

# Test-VM löschen
qm stop 999
qm destroy 999
```

## Terraform-Konfiguration anpassen

Nach dem Template-Setup, aktualisieren Sie die Terraform-Variablen:

```hcl
# terraform/terraform.tfvars
vm_template = "ubuntu-22.04-cloud-init"  # Template-Name
```

## Troubleshooting

### Problem: VM startet nicht

```bash
# VM-Konfiguration prüfen
qm config 9000

# VM-Logs prüfen
journalctl -u qemu-server@9000.service
```

### Problem: Cloud-init funktioniert nicht

```bash
# In der VM (nach SSH-Verbindung):
sudo cloud-init status
sudo cloud-init logs
```

### Problem: SSH-Verbindung fehlschlägt

```bash
# SSH-Schlüssel prüfen
cat /root/.ssh/id_rsa.pub

# VM-Konsole über Proxmox öffnen
# Web-UI → VM → Console
```

## Erweiterte Konfiguration

### Custom Cloud-init Config

Erstellen Sie eine custom Cloud-init Konfiguration:

```yaml
# /var/lib/vz/snippets/spark-cloud-init.yml
#cloud-config
packages:
  - qemu-guest-agent
  - curl
  - wget
  - git

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent

write_files:
  - path: /etc/motd
    content: |
      Welcome to Spark Infrastructure VM
      Managed by Terraform + Ansible
```

Dann in Terraform verwenden:

```hcl
cicustom = "user=local:snippets/spark-cloud-init.yml"
```

## Backup-Strategie

```bash
# Template sichern
vzdump 9000 --mode snapshot --storage local

# Template wiederherstellen
qmrestore /var/lib/vz/dump/vzdump-qemu-9000-*.tar.zst 9000
```

## Nächste Schritte

Nach erfolgreichem Template-Setup:

1. **Terraform konfigurieren** → `terraform/terraform.tfvars`
2. **Spark Infrastructure deployen** → `./hack/deploy.sh`
3. **VMs überwachen** → Proxmox Web-UI

Das Template ist jetzt bereit für die automatische VM-Erstellung durch Terraform!
