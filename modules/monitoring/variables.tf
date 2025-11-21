variable "location" {
  description = "Azure region for monitoring resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for monitoring resources."
  type        = string
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "log_identity_id" {
  description = "User-assigned identity ID used by Log Analytics."
  type        = string
}

variable "log_identity_principal_id" {
  description = "Principal ID for the logging identity."
  type        = string
}

variable "metrics_publisher_principal_id" {
  description = "Principal ID allowed to publish metrics to the DCR."
  type        = string
}

variable "monitoring_settings" {
  description = "Configuration for monitoring components."
  type = object({
    log_analytics = object({
      name              = string
      sku               = string
      retention_in_days = number
    })
    storage_account = object({
      name                         = string
      account_tier                 = string
      account_replication_type     = string
      access_tier                  = string
      min_tls_version              = string
      allow_nested_items_to_be_public = bool
      public_network_access_enabled   = bool
      network_rules = object({
        default_action = string
        bypass         = list(string)
        ip_rules       = list(string)
      })
    })
    storage_role_name = string
    metrics_publisher_role_name = string
    dcr = object({
      name               = string
      destination_name   = string
      data_flow_streams  = list(string)
      performance_counters = object({
        streams                       = list(string)
        sampling_frequency_in_seconds = number
        counter_specifiers            = list(string)
        name                          = string
      })
      event_log_name  = string
      event_log_queries = list(string)
      iis_logs = object({
        streams         = list(string)
        name            = string
        log_directories = list(string)
      })
    })
    storage_management_policy = object({
      rule_name            = string
      prefix_match         = list(string)
      tier_to_cool_after_days    = number
      tier_to_archive_after_days = number
    })
    linked_storage_data_source_type = string
    data_export = object({
      name        = string
      table_names = list(string)
      enabled     = bool
    })
  })
}
