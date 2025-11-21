variable "location" {
  description = "Azure region for the Key Vault."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the Key Vault."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID."
  type        = string
}

variable "current_object_id" {
  description = "Current principal object ID for RBAC assignments."
  type        = string
}

variable "admin_username" {
  description = "Admin username stored in Key Vault."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for diagnostics."
  type        = string
}

variable "key_vault_settings" {
  description = "Configuration for Key Vault and secrets."
  type = object({
    name                        = string
    sku_name                    = string
    soft_delete_retention_days  = number
    rbac_authorization_enabled  = bool
    diagnostics_name            = string
    purpose_tag                 = string
    network_acls = object({
      bypass         = string
      default_action = string
    })
    secrets_officer_role_name       = string
    certificates_officer_role_name  = string
    secrets = object({
      admin_username_name        = string
      admin_password_name        = string
      admin_password_content_type = string
    })
    password_policy = object({
      length           = number
      special          = bool
      override_special = string
      min_lower        = number
      min_upper        = number
      min_numeric      = number
      min_special      = number
    })
  })
}
