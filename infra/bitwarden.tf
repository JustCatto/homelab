resource "proxmox_virtual_environment_vm" "vaultwarden" {
  name      = var.vm_name
  node_name = var.proxmox_node_name
  vm_id     = var.vm_id
  started   = true
  on_boot   = true

  clone {
    vm_id     = var.proxmox1_debian_template_vm_id
    node_name = var.proxmox_node_name
    full      = true
  }

  cpu {
    cores = var.vm_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  disk {
    datastore_id = var.proxmox_datastore_id
    interface    = "scsi0"
    size         = var.vm_disk_gb
  }

  network_device {
    bridge = var.proxmox_network_bridge
  }

  initialization {
    datastore_id = var.proxmox_datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = var.vm_admin_user
      keys     = [var.vaultwarden_ssh_public_key]
    }
  }

  agent {
    enabled = true
  }
}

output "vaultwarden_vm_id" {
  value = proxmox_virtual_environment_vm.vaultwarden.vm_id
}

output "vaultwarden_ipv4_addresses" {
  description = "Guest-agent reported IPv4 addresses; look up the DHCP lease if the agent has not started yet."
  value       = proxmox_virtual_environment_vm.vaultwarden.ipv4_addresses
}
