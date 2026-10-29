variable "proxmox_endpoint" {
  description = "Proxmox API endpoint (not the UI URL with its # fragment)."
  type        = string
  default     = "https://proxmox.cattoindustries.com:8006/"
}

variable "proxmox_api_token" {
  description = "Dedicated least-privilege token in user@realm!tokenid=secret format. Set via TF_VAR_proxmox_api_token or an untracked tfvars file."
  type        = string
  sensitive   = true
}

variable "hcloud_token" {
  sensitive = true
}

variable "proxmox_insecure" {
  description = "Only set true for a self-signed Proxmox API certificate you cannot yet trust."
  type        = bool
  default     = false
}

variable "proxmox_node_name" {
  description = "Proxmox node hosting both the Debian template and the VM."
  type        = string
}

variable "proxmox1_debian_template_vm_id" {
  description = "Debian cloud-init template ID on proxmox1; used by the Vaultwarden clone."
  type        = number
  default     = 9001
}

variable "proxmox2_debian_template_vm_id" {
  description = "Debian cloud-init template ID on proxmox2, available for VMs placed there."
  type        = number
  default     = 9002
}

variable "proxmox_datastore_id" {
  description = "Datastore supporting VM disks and cloud-init snippets/images."
  type        = string
  default     = "local-lvm"
}

variable "proxmox_network_bridge" {
  description = "Bridge with DHCP and outbound connectivity."
  type        = string
  default     = "vmbr0"
}

variable "shared_ssh_public_key" {
  description = "HomeLab public key installed on the Debian templates via bootstrap; reserved for shared-key VMs. Vaultwarden instead uses vaultwarden_ssh_public_key."
  type        = string
}

variable "vaultwarden_ssh_public_key" {
  description = "Vaultwarden-specific public key to inject into its clone, replacing the template's cloud-init SSH key setting. Never use a private key here."
  type        = string
}

variable "vm_admin_user" {
  description = "Cloud-init SSH user; the bootstrap template uses catto by default."
  type        = string
  default     = "catto"
}

variable "vm_name" {
  type    = string
  default = "vaultwarden"
}

variable "vm_id" {
  description = "Unique VM ID on this Proxmox cluster."
  type        = number
}

variable "vm_cpu_cores" {
  type    = number
  default = 2
}

variable "vm_memory_mb" {
  type    = number
  default = 2048
}

variable "vm_disk_gb" {
  type    = number
  default = 32
}
