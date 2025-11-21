variable "location" {
  description = "Azure region for load balancer resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for load balancer resources."
  type        = string
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "load_balancer_settings" {
  description = "Load balancer, public IP, and pool configuration."
  type = object({
    public_ip = object({
      name                    = string
      allocation_method       = string
      sku                     = string
      zones                   = list(string)
      ip_version              = string
      idle_timeout_in_minutes = number
    })
    load_balancer = object({
      name          = string
      sku           = string
      frontend_name = string
    })
    backend_pools = object({
      web_name  = string
      mgmt_name = string
    })
    probes = object({
      https = object({
        name                = string
        protocol            = string
        port                = number
        interval_in_seconds = number
        number_of_probes    = number
      })
      rdp = object({
        name                = string
        protocol            = string
        port                = number
        interval_in_seconds = number
        number_of_probes    = number
      })
    })
    rules = object({
      https = object({
        name                  = string
        protocol              = string
        frontend_port         = number
        backend_port          = number
        floating_ip_enabled   = bool
        disable_outbound_snat = bool
      })
      outbound = object({
        name                     = string
        protocol                 = string
        allocated_outbound_ports = number
        idle_timeout_in_minutes  = number
      })
      rdp = object({
        name                  = string
        protocol              = string
        frontend_port         = number
        backend_port          = number
        disable_outbound_snat = bool
      })
    })
  })
}
