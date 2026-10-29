variable "cloudflare_api_token" {
  description = "Cloudflare account API token with Zone:Read, DNS:Read and DNS:Edit for cattoindustries.com."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.cloudflare_api_token)) > 0 && var.cloudflare_api_token != "REPLACE_WITH_CLOUDFLARE_ACCOUNT_API_TOKEN"
    error_message = "Set cloudflare_api_token to a real, nonempty Cloudflare API token."
  }
}

variable "cattoindustries_records" {
  description = "DNS-only A, AAAA or CNAME records to manage in Cloudflare's existing cattoindustries.com zone. Import existing records before applying."
  type = map(object({
    type  = string
    value = string
  }))

  validation {
    condition = alltrue([
      for name, record in var.cattoindustries_records :
      can(regex("^(\\*|[a-zA-Z0-9-]+)$", name)) &&
      contains(["A", "AAAA", "CNAME"], record.type) &&
      trimspace(record.value) != "" && !startswith(record.value, "REPLACE_")
    ])
    error_message = "Each record needs a single-label name (or *), type A, AAAA or CNAME, and a non-placeholder target."
  }
}
