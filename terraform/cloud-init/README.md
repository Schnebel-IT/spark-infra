# Cloud-Init Configuration

This directory contains cloud-init configuration files for the Kubernetes VMs.

## Files

- `user-data-k8s.yml`: Cloud-init user-data configuration for Kubernetes nodes

## Usage

The cloud-init files need to be uploaded to your Proxmox server as snippets before running Terraform.

### Upload to Proxmox

1. Copy the `user-data-k8s.yml` file to your Proxmox server:
   ```bash
   scp user-data-k8s.yml root@your-proxmox-server:/var/lib/vz/snippets/
   ```

2. Alternatively, you can use the Proxmox web interface:
   - Go to your Proxmox node
   - Navigate to "local" storage
   - Click on "Content"
   - Select "Snippets" from the dropdown
   - Upload the `user-data-k8s.yml` file

## Configuration Details

The cloud-init configuration includes:
- System updates and essential packages
- Kubernetes prerequisites (bridge netfilter, IP forwarding)
- Swap disabled (required for Kubernetes)
- SSH key configuration
- User setup with sudo privileges
- Network and system optimizations

## Note

Make sure your Proxmox template supports cloud-init and has the cloud-init package installed.