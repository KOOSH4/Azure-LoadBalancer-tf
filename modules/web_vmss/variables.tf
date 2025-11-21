variable "location" {
  description = "Azure region for the VMSS."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the VMSS."
  type        = string
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "subnet_id" {
  description = "Subnet for the VMSS."
  type        = string
}

variable "backend_pool_id" {
  description = "Backend pool ID for the VMSS."
  type        = string
}

variable "asg_id" {
  description = "Application security group ID for the VMSS."
  type        = string
}

variable "health_probe_id" {
  description = "Health probe ID for load balancer."
  type        = string
}

variable "identity_ids" {
  description = "User assigned identities to attach."
  type        = list(string)
}

variable "dcr_id" {
  description = "Data collection rule ID."
  type        = string
}

variable "admin_username" {
  description = "Admin username for the VMSS."
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Admin password for the VMSS."
  type        = string
  sensitive   = true
}

variable "vmss_sku" {
  description = "VM SKU for the VMSS."
  type        = string
}

variable "vmss_zone1_min_instances" {
  description = "Minimum instances for VMSS."
  type        = number
}

variable "vmss_zone1_max_instances" {
  description = "Maximum instances for VMSS."
  type        = number
}

variable "business_hours_min_instances" {
  description = "Minimum instances during business hours."
  type        = number
}

variable "business_hours_start" {
  description = "Hour to start business hours."
  type        = number
}

variable "business_hours_end" {
  description = "Hour to end business hours."
  type        = number
}

variable "autoscale_cpu_threshold_out" {
  description = "CPU threshold to scale out."
  type        = number
}

variable "autoscale_cpu_threshold_in" {
  description = "CPU threshold to scale in."
  type        = number
}

variable "autoscale_notification_emails" {
  description = "Emails for autoscale notifications."
  type        = list(string)
}

variable "vmss_settings" {
  description = "Configuration for VMSS."
  type = object({
    name               = string
    zones              = list(string)
    zone_balance       = bool
    upgrade_mode       = string
    network_interface_name = string
    ip_configuration_name  = string
    source_image = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    os_disk = object({
      caching              = string
      storage_account_type = string
    })
    extension = object({
      name                       = string
      publisher                  = string
      type                       = string
      type_handler_version       = string
      auto_upgrade_minor_version = bool
    })
    automatic_instance_repair = object({
      enabled      = bool
      grace_period = string
    })
    dcra_name  = string
    extra_tags = map(string)
    autoscale = object({
      name                         = string
      default_profile_name         = string
      business_hours_profile_name  = string
      after_hours_profile_name     = string
      timezone                     = string
      business_days                = list(string)
      after_hours_max_instances    = number
      memory_threshold_bytes       = number
    })
  })
}
