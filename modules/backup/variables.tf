variable "location" {
  description = "Azure region for backup resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for backup resources."
  type        = string
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "backup_settings" {
  description = "Backup vault and policy settings."
  type = object({
    vault_name                    = string
    vault_sku                     = string
    storage_mode_type             = string
    soft_delete_enabled           = bool
    public_network_access_enabled = bool
    immutability                  = string
    purpose_tag                   = string
    policy = object({
      name                        = string
      policy_type                 = string
      timezone                    = string
      instant_restore_retention_days = number
      backup = object({
        frequency     = string
        time          = string
        hour_interval = number
        hour_duration = number
      })
      retention_daily_count = number
    })
  })
}
