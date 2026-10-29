# The public zone already exists at Cloudflare; do not recreate or redelegate it.
data "cloudflare_zone" "cattoindustries" {
  filter = {
    name = "cattoindustries.com"
  }
}

resource "cloudflare_dns_record" "cattoindustries" {
  for_each = var.cattoindustries_records

  zone_id = data.cloudflare_zone.cattoindustries.id
  name    = "${each.key}.cattoindustries.com"
  type    = each.value.type
  content = each.value.value
  ttl     = 300
  proxied = false
}
