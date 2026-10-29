resource "hcloud_ssh_key" "shared" {
  name       = "homelab-shared"
  public_key = var.shared_ssh_public_key
}

resource "hcloud_firewall" "debian_4gb_hel1" {
  name = "firewall-1"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    description = "HTTP-01"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    description = "HTTPS"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "3478"
    description = "STUN"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

}

resource "hcloud_server" "debian_4gb_hel1" {
  name               = "debian-4gb-hel1-1"
  server_type        = "cx23"
  delete_protection  = true
  rebuild_protection = true
  location           = "hel1"
  image              = "debian-13"
  ssh_keys           = [hcloud_ssh_key.shared.id]
  firewall_ids       = [hcloud_firewall.debian_4gb_hel1.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  lifecycle {
    ignore_changes  = [ssh_keys]
    prevent_destroy = true
  }
}

output "hetzner_ipv4_address" {
  description = "Public IPv4 address of the Hetzner Debian server."
  value       = hcloud_server.debian_4gb_hel1.ipv4_address
}
