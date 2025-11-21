variable "location" {
  description = "Azure region for networking components."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for networking components."
  type        = string
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics."
  type        = string
}

variable "allowed_rdp_cidr" {
  description = "CIDR allowed to access management resources."
  type        = string
}

variable "network_settings" {
  description = "Network configuration."
  type = object({
    asg = object({
      web = object({
        name       = string
        extra_tags = map(string)
      })
      mgmt = object({
        name       = string
        extra_tags = map(string)
      })
    })
    nsg = object({
      apps = object({
        name             = string
        diagnostics_name = string
      })
      mgmt = object({
        name             = string
        diagnostics_name = string
      })
      rules = object({
        apps_allow_rdp_from_mgmt = object({
          name                 = string
          priority             = number
          direction            = string
          protocol             = string
          source_port_range    = string
          destination_port_range = string
        })
        apps_allow_https_from_mgmt = object({
          name                 = string
          priority             = number
          direction            = string
          protocol             = string
          source_port_range    = string
          destination_port_range = string
        })
        apps_allow_https_from_internet = object({
          name                  = string
          priority              = number
          direction             = string
          protocol              = string
          source_port_range     = string
          destination_port_range = string
          source_address_prefix = string
        })
        apps_allow_health_probe = object({
          name                     = string
          priority                 = number
          direction                = string
          protocol                 = string
          source_port_range        = string
          destination_port_range   = string
          source_address_prefix    = string
          destination_address_prefix = string
        })
        mgmt_allow_rdp_from_specific_ip = object({
          name                 = string
          priority             = number
          direction            = string
          protocol             = string
          source_port_range    = string
          destination_port_range = string
        })
      })
    })
    vnet = object({
      name          = string
      address_space = list(string)
    })
    subnets = object({
      apps = object({
        name                                     = string
        address_prefixes                         = list(string)
        private_endpoint_network_policies        = string
        private_link_service_network_policies_enabled = bool
      })
      mgmt = object({
        name                                     = string
        address_prefixes                         = list(string)
        private_endpoint_network_policies        = string
        private_link_service_network_policies_enabled = bool
      })
    })
  })
}
