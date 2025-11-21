variable "location" {
  description = "Azure region for the management VM."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the management VM."
  type        = string
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "subnet_id" {
  description = "Subnet for the management VM."
  type        = string
}

variable "asg_id" {
  description = "ASG ID for management traffic."
  type        = string
}

variable "backend_pool_id" {
  description = "Backend pool ID for LB association."
  type        = string
}

variable "admin_username" {
  description = "Admin username for the management VM."
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Admin password for the management VM."
  type        = string
  sensitive   = true
}

variable "mgmt_vm_settings" {
  description = "Configuration for the management VM."
  type = object({
    nic_name             = string
    ip_configuration_name = string
    private_ip_allocation = string
    private_ip_version    = string
    vm_name              = string
    vm_size              = string
    source_image = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    os_disk = object({
      caching              = string
      storage_account_type = string
      name                 = string
    })
    secure_boot_enabled = bool
    vtpm_enabled        = bool
  })
}
