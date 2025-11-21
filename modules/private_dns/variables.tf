variable "resource_group_name" {
  description = "Resource group for DNS resources."
  type        = string
}

variable "vnet_id" {
  description = "Virtual network ID to link."
  type        = string
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "dns_settings" {
  description = "Settings for the private DNS zone."
  type = object({
    zone_name            = string
    vnet_link_name       = string
    registration_enabled = bool
    a_record_name        = string
    a_record_ttl         = number
    a_record_values      = list(string)
  })
}
