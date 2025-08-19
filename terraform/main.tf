# Spark Infrastructure - Proxmox Terraform Configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

# Proxmox Provider Configuration
provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = var.proxmox_tls_insecure
  pm_parallel     = 3
  pm_timeout      = 600
}

# Data source for template
data "proxmox_virtual_environment_datastores" "available" {
  node_name = var.proxmox_node
}

# Create VMs using modules
module "kubernetes_masters" {
  source = "./modules/vm"
  
  count = var.k8s_master_count
  
  vm_name     = "spark-conductor-${format("%02d", count.index + 1)}"
  target_node = var.proxmox_node
  template    = var.vm_template
  
  cores    = var.k8s_master_cores
  memory   = var.k8s_master_memory
  disk_size = var.k8s_master_disk_size
  
  network_bridge = var.network_bridge
  ip_address     = "${var.network_prefix}.${101 + count.index}"
  gateway        = var.network_gateway
  
  ssh_keys = [var.ssh_public_key]
  
  tags = ["kubernetes", "master", "spark"]
}

module "kubernetes_workers" {
  source = "./modules/vm"
  
  count = var.k8s_worker_count
  
  vm_name     = "spark-executor-${format("%02d", count.index + 1)}"
  target_node = var.proxmox_node
  template    = var.vm_template
  
  cores    = var.k8s_worker_cores
  memory   = var.k8s_worker_memory
  disk_size = var.k8s_worker_disk_size
  
  network_bridge = var.network_bridge
  ip_address     = "${var.network_prefix}.${110 + count.index}"
  gateway        = var.network_gateway
  
  ssh_keys = [var.ssh_public_key]
  
  tags = ["kubernetes", "worker", "spark"]
}

module "monitoring_vms" {
  source = "./modules/vm"
  
  count = var.monitoring_count
  
  vm_name     = "spark-observer-${format("%02d", count.index + 1)}"
  target_node = var.proxmox_node
  template    = var.vm_template
  
  cores    = var.monitoring_cores
  memory   = var.monitoring_memory
  disk_size = var.monitoring_disk_size
  
  network_bridge = var.network_bridge
  ip_address     = "${var.network_prefix}.${120 + count.index}"
  gateway        = var.network_gateway
  
  ssh_keys = [var.ssh_public_key]
  
  tags = ["monitoring", "spark"]
}

module "development_vms" {
  source = "./modules/vm"
  
  count = var.development_count
  
  vm_name     = "spark-builder-${format("%02d", count.index + 1)}"
  target_node = var.proxmox_node
  template    = var.vm_template
  
  cores    = var.development_cores
  memory   = var.development_memory
  disk_size = var.development_disk_size
  
  network_bridge = var.network_bridge
  ip_address     = "${var.network_prefix}.${130 + count.index}"
  gateway        = var.network_gateway
  
  ssh_keys = [var.ssh_public_key]
  
  tags = ["development", "spark"]
}
