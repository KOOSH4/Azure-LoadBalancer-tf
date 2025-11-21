variable "location" {
  description = "Azure region for private endpoints."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for private endpoints."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for private endpoints."
  type        = string
}

variable "storage_account_id" {
  description = "Target storage account ID."
  type        = string
}

variable "recovery_services_vault_id" {
  description = "Target Recovery Services Vault ID."
  type        = string
}

variable "private_endpoint_settings" {
  description = "Settings for private endpoints."
  type = object({
    storage = object({
      name              = string
      connection_name   = string
      subresource_names = list(string)
    })
    rsv = object({
      name              = string
      connection_name   = string
      subresource_names = list(string)
    })
  })
}
