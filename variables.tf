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
  description = "The Client ID of the Managed Identity."
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "The Azure Tenant ID."
  type        = string
  sensitive   = true
}