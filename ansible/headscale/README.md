# Headscale (Debian)

This playbook installs the official Headscale Debian package at the version set in `versions.yml` (default **0.26.1**) and Debian's Caddy package on a **dedicated Debian VM**. It configures Headscale with persistent SQLite and Noise-key storage under `/var/lib/headscale`, MagicDNS, optional `cattoindustries.com` split-DNS resolvers, a database-backed HuJSON policy, and a loopback-only control API behind Caddy's automatic HTTPS proxy. The gRPC and metrics listeners stay on loopback; no embedded DERP server is enabled. The default Tailscale DERP map is fetched from Tailscale, so clients may use third-party relay infrastructure.

## Before running

- Provide a Debian VM reachable over SSH with sudo access; this playbook does not create the VM or configure the host firewall. Do not run it on a host with another Caddy deployment: it owns `/etc/caddy/Caddyfile`.
- Point a public DNS A record (and AAAA if used) for the Headscale hostname to the VM, and allow inbound TCP **80 and 443** through the host/network firewall and any NAT. Caddy needs port 80 for automatic public certificate issuance/renewal; clients need port 443. Permit outbound HTTPS to GitHub release assets, ACME, and Tailscale's DERP map. A non-public deployment needs a separately configured trusted TLS certificate and reachable DNS instead.
- Set `tailnet_domain` to `tailscale.cattoindustries.com` for `<device>.tailscale.cattoindustries.com` MagicDNS names. The earlier suggested `<device>.tailnet.cattoindustries.com` is a different domain and is not configured here. The tailnet domain must differ from the control server hostname.
- Leave `split_dns_servers: []` for the initial deployment. Once your authoritative DNS servers are enrolled, tagged, and reachable, add their tailnet IPv4 addresses in `100.64.0.0/24` (for example `100.64.0.53` and `100.64.0.54`) and rerun Ansible. An empty list emits no split-DNS rule; a populated list sets split DNS for `cattoindustries.com` (DNS suffixes do not use `*.`). No global nameservers are overridden, and these servers do not need to forward unrelated domains. Because the MagicDNS domain is nested inside that suffix, verify device-name resolution on enrolled clients; the specific MagicDNS suffix must resolve locally rather than being sent to these non-forwarding servers.
- Clients using Headscale DNS must enable Tailscale's `--accept-dns` option (Vaultwarden's existing playbook explicitly disables this); configure private DNS or use the tailnet domain for node names accordingly.

## Deploy

From this directory:

```sh
cp inventory.ini.example inventory.ini
cp secrets.yml.example secrets.yml
# Edit inventory.ini and secrets.yml (real DNS names, resolvers and admin username).
ansible-playbook --syntax-check site.yml
ansible-playbook site.yml
```

The real `inventory.ini` and `secrets.yml` are ignored by Git. Set `headscale_admin_user` to a full email-style name such as `user@example.com`; the policy group uses that value exactly, without appending `@`. Changing this value creates a new Headscale user if missing; it does not rename or migrate existing users or their nodes. Set `headscale_version` in `versions.yml` to change the pinned version (or override it in your ignored `secrets.yml`); review upstream release notes and back up the database and keys before upgrading. The playbook creates the configured admin user if missing, renders and checks `templates/policy.hujson`, then applies it with `headscale policy set --file` in database mode when its file or Headscale configuration changes. Edit the policy template and verify that its default-deny grants permit intended traffic **before** deployment; apply from a non-tailnet SSH/console session to avoid lockout. `"ssh": []` denies Tailscale SSH via policy; it does not disable ordinary OpenSSH or remove a client-side `tailscale up --ssh` setting. The playbook does not provision external DNS, open firewall ports, create pre-authentication keys, or enroll clients.

## Verify and enroll

On the VM, check `sudo systemctl status headscale caddy`, `sudo journalctl -u headscale -u caddy`, `sudo headscale policy get`, and `curl -I https://<headscale_domain>/` (a Headscale 404 response is fine if TLS succeeds). The admin user from `secrets.yml` is created automatically. Create a pre-authentication key for that user as root:

```sh
sudo headscale preauthkeys create --user <headscale_admin_user>
```

Store the printed key privately; run `tailscale up --login-server=https://<headscale_domain> --auth-key=<key>` on a client (avoid leaking the key in shell history, logs or process listings). For the Vaultwarden VM, put the same HTTPS URL and a valid key in its ignored `ansible/vaultwarden/secrets.yml`; the Vaultwarden playbook handles enrollment. The HuJSON grants are restrictive; test expected connections, Tailscale SSH denial, and DNS on actual enrolled clients. Headscale configuration changes to the base domain can rename MagicDNS device names.

Back up `/var/lib/headscale` (including `db.sqlite`, its WAL files and `noise_private.key`) and the Caddy state under `/var/lib/caddy` securely. Stop Headscale briefly or use SQLite's online backup mechanism to get a consistent database snapshot. Restoring only the database without its key can disrupt clients. Test backup restoration before upgrades. This setup has not been applied to a live VM by this repository.
