# ============================================================================
# VARIABLES.TF - Updated for Key Vault Integration
# ============================================================================

variable "location" {
  description = "The Azure region to deploy resources into."
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
  default     = "rg-kolad-sch"
}

variable "subscription_id" {
  description = "The Azure subscription ID."
  type        = string
}

variable "client_id" {
  description = "The Client ID of the Managed Identity (for OIDC authentication)."
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "The Azure Tenant ID."
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Admin username for Windows VMs (stored in Key Vault)"
  type        = string
  default     = "AzureMinions"
  sensitive   = true
}

variable "allowed_rdp_ip" {
  description = "IP address allowed to RDP into management VM"
  type        = string
  default     = "109.41.113.107/32"
  
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.allowed_rdp_ip))
    error_message = "The allowed_rdp_ip must be a valid CIDR notation (e.g., 109.41.113.107/32)."
  }
}