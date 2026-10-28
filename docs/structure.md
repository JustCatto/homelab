# Repository structure

- `bootstrap/README.md`: step-by-step Proxmox-node preparation, template creation, validation and Terraform handoff.
- `bootstrap/create-debian-template-9000.sh`: one-time script to download/verify a Debian 13 cloud image, install qemu-guest-agent and turn Proxmox VM 9000 into a template with the HomeLab public SSH key; run only on the target Proxmox node.
- `terraform/providers.tf`: Terraform and Proxmox provider version constraints; API endpoint/token/TLS configuration.
- `terraform/variables.tf`: cluster, template, network, VM sizing, stored HomeLab public key input and separate Vaultwarden SSH public-key input.
- `terraform/bitwarden.tf`: Debian VM cloned from the prebuilt cloud-init template, DHCP and Vaultwarden-specific SSH key initialization, guest-agent IP output.

- `terraform/terraform.tfvars.example`: non-secret sample values; copy to ignored `terraform.tfvars` and supply API token separately.
- `ansible/headscale/`: standalone Debian Headscale playbook, pinned upstream `.deb`, local inventory/settings examples, Headscale configuration and Caddy HTTPS proxy templates; see its `README.md` for DNS/port prerequisites and client enrollment.
- `ansible/vaultwarden/README.md`: service-specific prerequisites, local configuration, deployment command and verification.
- `ansible/vaultwarden/ansible.cfg`: selects the service-local `inventory.ini` when running Ansible from this directory.
- `ansible/vaultwarden/site.yml`: service playbook for host bootstrap and idempotent Compose reconciliation; loads service-local `secrets.yml` automatically and runs with sudo against the `vaultwarden` inventory group.
- `ansible/vaultwarden/inventory.ini.example`, `ansible/vaultwarden/secrets.yml.example`: examples for ignored real local inventory/secret vars alongside the service playbook.
- `ansible/vaultwarden/files/compose.yaml`: pinned application images, private backend network, persistent storage, container hardening and Tailscale-IP-only Caddy port.
- `ansible/vaultwarden/files/Caddyfile`: Caddy internal-CA HTTPS and reverse proxy to Vaultwarden.
- `ansible/vaultwarden/files/sshd.local`: host SSH Fail2ban jail using systemd and nftables.
- `ansible/vaultwarden/templates/vaultwarden.nft.j2`: isolated default-deny ingress policy and Docker DNAT guard; rendered with the assigned Tailscale IPv4.
- `ansible/vaultwarden/files/apply-firewall`, `ansible/vaultwarden/files/vaultwarden-firewall.service`: atomic per-table rules validation/application and boot persistence without flushing other firewall owners.
- `ansible/vaultwarden/files/vaultwarden-compose.service`: waits for Tailscale and the firewall before reconciling the Compose stack on boot.
- `ansible/vaultwarden/templates/vaultwarden.env.j2`: secret-bearing environment file rendered to the VM with root-only permissions; PHC hash quoting matters.
- `docs/`: design, setup and deployment/operations notes. `AGENTS.MD` is the canonical agent guide; `CLAUDE.MD` points to it.
- `.gitignore`: keeps local credentials and Terraform state out of Git. Existing tracked files or remote Terraform backends need separate protection.

The `/opt/vaultwarden` directory on the VM is Ansible-managed, not part of the source tree. Caddy volumes and `data/` are runtime data, not generated source files. Headscale can be installed on its own Debian VM with `ansible/headscale/`; no Headscale VM is currently provisioned by Terraform. When adding another service, create its own `ansible/<service>/` directory with its playbook, inventory, variables and files rather than putting them at the `ansible/` root. Add a separate Terraform resource as needed, while reusing `shared_ssh_public_key` for new VMs.
