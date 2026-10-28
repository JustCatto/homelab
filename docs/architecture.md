# Architecture

This repository provides a one-time Proxmox-node bootstrap script in `bootstrap/` to build the Debian 13 cloud-init template, then provisions one Debian VM for a self-hosted Vaultwarden password manager. Terraform talks to the Proxmox VE API at `https://proxmox.cattoindustries.com:8006/` by default. The provided browser URL (`https://proxmox.cattoindustries.com/#v1:0:18:4:::::::`) is a UI fragment, not an API endpoint; confirm the actual API endpoint, port and trusted TLS certificate before applying. No cluster access or deployment is assumed.

```text
Proxmox VE API <- Terraform (API token)
    |
    +-- Debian cloud-init template (HomeLab SSH key) -> vaultwarden VM (DHCP, own SSH key)
                                    |
                         Ansible (SSH, sudo)
                                    |
                      Headscale <- tailscaled (tailscale0, own IPv4)
                                    |
              nftables (private ingress) + Docker + Fail2ban (host sshd)
                                    |
           Caddy (HTTPS 443, bound to Tailscale IPv4 only)
                     -> Vaultwarden (private port 8080, UID/GID 1000)
                           -> /opt/vaultwarden/data
```

This VM is enrolled in an existing Headscale network using Tailscale's official Debian packages and an untracked pre-authentication key. The playbook uses the actual `tailscale ip -4` address when binding Caddy; DNS on enrolled clients must resolve `vaultwarden_domain` to that address. The VM declines Headscale-provided DNS, but clients may use private DNS. No NPM or WAN port forwarding is involved. Caddy issues an internal CA certificate (`tls internal`) so HTTPS works without public ACME challenges; clients must install the Caddy root CA or you must provide a separately managed DNS-01 certificate. Proxmox authentication uses a dedicated, least-privilege API token and certificate verification is on by default.

Vaultwarden stores its SQLite database, keys and attachments in `/opt/vaultwarden/data`; Caddy's certificate and configuration state live in named Docker volumes. These are persistent and must be backed up. The deployment disables new user signups/invitations, uses a hashed admin token, and has no Vaultwarden host port. The service-specific nftables table has a default-drop INPUT chain, allowing established/related traffic, loopback, ICMP/ICMPv6, DHCP lease replies (UDP 67 → 68), inbound WireGuard UDP (default 41641), TCP 22/443 on `tailscale0`, and LAN emergency SSH from `192.168.1.0/24`. Outbound is unrestricted. Docker-published ports can bypass INPUT via DNAT, so a dedicated FORWARD rule rejects non-Tailscale traffic targeting the original Tailscale IPv4:443. The loader only replaces its own table, retaining Docker, Tailscale and Fail2ban dynamic rules, and a systemd unit persists the policy across reboot. Caddy's 443 port is published only on the Tailscale IPv4; Vaultwarden has no host port. Headscale ACLs still define which enrolled clients may connect. Fail2ban's `[sshd]` jail protects SSH, not Vaultwarden login attempts; application-level bans would need a separate, tested design.

The bootstrap script creates the reusable Proxmox template with its stored HomeLab public SSH key separately from Terraform state. Vaultwarden's Terraform resource sets its own `vaultwarden_ssh_public_key` on the clone, replacing the template's cloud-init key configuration rather than adding a key. Terraform manages cloned VM lifecycle only; Ansible installs system packages and deploys files; Compose runs the application. Terraform state, host data, and credentials are not interchangeable backups.
