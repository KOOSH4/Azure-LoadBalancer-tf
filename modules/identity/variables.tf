variable "location" {
  description = "Azure region for the identities."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to contain the identities."
  type        = string
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "identity_names" {
  description = "Names for the user assigned identities."
  type = object({
    backup = string
    dcr    = string
    log    = string
  })
}
