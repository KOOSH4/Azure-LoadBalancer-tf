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
