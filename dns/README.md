# Cloudflare DNS

The `dns/` Terraform root manages selected **DNS-only** records in the existing public `cattoindustries.com` Cloudflare zone. The zone is looked up, not created; unrelated records remain untouched. Public DNS may publish a Tailscale IP for `bitwarden.cattoindustries.com` without making Vaultwarden publicly reachable. Dynamic `<node>.tailscale.cattoindustries.com` names are still Headscale MagicDNS, not Cloudflare DNS records. Keep `proxied = false` for the managed records; Cloudflare's HTTP proxy is not a tailnet gateway.

Set `cloudflare_api_token` in ignored `terraform.tfvars` to your Cloudflare account API token scoped to this zone with `Zone:Read`, `DNS:Read`, and `DNS:Edit` (or supply it through `TF_VAR_cloudflare_api_token`). This is an API **token**, not the global API key; no account ID is needed to look up the existing zone by name. Do not commit credentials, ignored `terraform.tfvars`, state or plans. Set the targets in ignored `terraform.tfvars` as shown in `terraform.tfvars.example`; the two configured names are `bitwarden` and `tailscale`. A Tailscale address in public DNS reveals the IP even though tailnet access remains controlled by Headscale.

The existing public records were confirmed on Cloudflare. To **adopt** them into this Terraform root without trying to create duplicates, first back up `dns/terraform.tfstate`, then run from `dns/`:

```sh
terraform init -backend=false -upgrade
terraform import 'cloudflare_dns_record.cattoindustries["bitwarden"]' 'b34f0a22ae6d9ea6eccb3e6bf5d4413c/a9ec9b89397ea11e82ac5f39fb8e7225'
terraform import 'cloudflare_dns_record.cattoindustries["tailscale"]' 'b34f0a22ae6d9ea6eccb3e6bf5d4413c/8fc0e70936f37b33a755a54ba69b60c8'
terraform plan
```

These IDs were read from Cloudflare while preparing this migration; recheck them if the records are replaced before import. **Do not apply the initial plan blindly:** the configured `tailscale` target currently differs from the live Cloudflare A record. Verify which public address should serve the Headscale login endpoint, that it is reachable and presents a valid certificate, then update `terraform.tfvars` or approve the intended change. The `bitwarden` target matched the live record when checked. For any additional records, add them to the map only after checking whether they already exist; import existing ones before applying. Do not recreate old `dns`, `dns1`, or `dns2` service names.

After `terraform plan` shows only approved changes, run `terraform apply`. Test public DNS from outside the tailnet, Vaultwarden HTTPS, and Headscale client enrollment before changing client resolvers or retiring old infrastructure. The repo changes alone do not modify live Cloudflare records or machines.
