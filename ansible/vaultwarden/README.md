# Vaultwarden on Headscale

Run this playbook from this directory on your workstation. It installs Tailscale from its official Debian repository and joins the existing Headscale network, installs Docker and host Fail2ban, configures a dedicated nftables firewall table, and runs Vaultwarden privately behind Caddy. NPM and public port forwarding are **not** part of this deployment.

## Prerequisites

1. Create the Debian template and VM following [`docs/setup.md`](../../docs/setup.md). Have an SSH key for the `catto` user (or your `vm_admin_user`), and verify sudo works. Keep Proxmox console access available in case networking fails. The VM needs outbound DNS, Headscale/DERP connectivity, Debian and Docker package repositories, and container image access. The firewall permits outbound traffic, including SMTP2GO; it does not configure SMTP2GO itself.
2. Make a Headscale **pre-authentication key** for this VM. Add the following to your existing, untracked `secrets.yml` (see `secrets.yml.example` for names; do not commit real values):
   - `headscale_url`: your control-server URL, including `https://` and any nonstandard port.
   - `headscale_auth_key`: a valid Headscale pre-authentication key. A single-use key may expire; it is needed only for the first enrolment or a later re-enrolment. Tailscale node state persists on the VM. The playbook does not print the key or write it to a managed file.
   - Keep `vaultwarden_domain` (hostname only) and the complete Argon2id `vaultwarden_admin_token` hash. Never paste the hash into `templates/vaultwarden.env.j2` or put a private SSH key in this repository. Protect `secrets.yml` with `chmod 600 secrets.yml`.
3. If you have not done so, copy `inventory.ini.example` to `inventory.ini` and set `ansible_host` to the VM's current reachable IP. During migration, keep LAN SSH from `192.168.1.0/24`; you may later change the inventory to the VM's Tailscale IPv4 when your Ansible controller is on Headscale. Your SSH client needs the private key matching the Terraform `vaultwarden_ssh_public_key`.
4. Ensure `vaultwarden_domain` resolves **on your Headscale clients** to this VM's assigned Tailscale IPv4 (Headscale DNS, split DNS, or client hosts entries). The playbook does not create DNS. Public DNS and port forwarding are unnecessary. `--accept-dns=false` applies to the VM's Tailscale client, not to other clients. If Headscale uses a private CA, install its root CA in the VM's OS trust store before enrolment; do not disable TLS verification.

## Deploy

From the repository root:

```sh
cd ansible/vaultwarden
ansible-playbook --syntax-check site.yml
ansible-playbook site.yml
```

If already here, run `ansible-playbook site.yml`. `ansible.cfg` selects the ignored local inventory and `site.yml` loads the ignored `secrets.yml` automatically. Add `--ask-become-pass` if sudo requires a password. The playbook installs and connects Tailscale **before** it changes the firewall or binds Caddy. It skips `tailscale up` when the daemon already reports `Running`, so ordinary reruns do not use the pre-auth key again. If the daemon reports a non-running state, supply a usable key for re-enrolment; a single-use key cannot be reused.

The playbook checks that `tailscaled` listens on UDP **41641** before installing the default-deny rule. If you configured a different UDP listening port on this VM, update `tailscale_udp_port` in `site.yml` to match it; check `sudo ss -lunp` on the VM. The firewall allows established traffic, loopback, ICMP/ICMPv6, inbound DHCP lease replies (UDP 67 → 68), SSH on `tailscale0` and from `192.168.1.0/24`, HTTPS on `tailscale0`, and the Tailscale UDP port; outbound is unrestricted. The additional FORWARD rule stops LAN clients from reaching Docker's Tailscale-bound published port via DNAT. The script only replaces its **own** nftables table, leaving Docker, Tailscale and Fail2ban rules intact. A persistent systemd unit reapplies it at boot. Direct access to this VM's Vaultwarden over the LAN is intentionally blocked, even if a LAN client tries its Tailscale IP via the LAN interface; LAN SSH remains available.

## HTTPS and validation

Caddy uses `tls internal` because this tailnet-only service cannot depend on public HTTP-01/TLS-ALPN-01 challenges. HTTPS is enabled, but **clients must trust Caddy's internal root CA** or certificate validation will fail. Once Caddy starts, obtain the *public root certificate only* from `/data/caddy/pki/authorities/local/root.crt` inside the Caddy container, install it as a trusted CA on each client that uses Vaultwarden, and verify the certificate matches `vaultwarden_domain`. Never distribute `/data/caddy/pki/authorities/local/root.key`. Alternatively, use a publicly trusted DNS-01 certificate with an appropriate DNS provider; that requires a separate, explicitly configured certificate workflow. Headscale pre-authentication keys do not provide HTTPS certificates.

The playbook performs a local, TLS-validation-disabled health probe using the configured hostname resolved to the discovered Tailscale IPv4. This checks service reachability **but does not prove client certificate trust**: verify a real client over Headscale with normal certificate validation. On the VM check `tailscale status`, `tailscale ip -4`, `sudo systemctl status vaultwarden-firewall.service`, `sudo nft list table inet vaultwarden_firewall`, `sudo fail2ban-client status sshd`, and `sudo docker compose --env-file .env -f compose.yaml ps` from `/opt/vaultwarden`. From an enrolled client try `https://<vaultwarden_domain>`; do not publish this address via NPM. A fresh install has no user accounts while signups/invitations are disabled; see [`docs/deployment.md`](../../docs/deployment.md) for onboarding, backup and recovery.

On failure, use the Proxmox console for recovery. The firewall loader validates the entire new nftables transaction before applying it, keeps established SSH connections, and permits fresh LAN SSH from `192.168.1.0/24`. If your controller is outside that subnet and not yet on Headscale, **do not run a firewall migration over SSH** without console access. For troubleshooting, `sudo systemctl stop vaultwarden-firewall.service` does **not** remove its nftables table; remove only `inet vaultwarden_firewall` from the console if necessary, never flush the global ruleset. Fail2ban covers host SSH only, not Vaultwarden logins.
