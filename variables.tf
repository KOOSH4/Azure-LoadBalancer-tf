# ============================================================================
# VARIABLES
# ============================================================================

variable "location" {
  description = "Azure region for deployments."
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Resource group name for all resources."
  type        = string
  default     = "rg-group5-sch"
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "client_id" {
  description = "Client ID for authentication."
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID."
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Admin username for Windows hosts."
  type        = string
  sensitive   = true
}

variable "allowed_rdp_ip" {
  description = "CIDR allowed to RDP into management resources."
  type        = string
  default     = "109.41.113.107/32"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.allowed_rdp_ip))
    error_message = "The allowed_rdp_ip must be a valid CIDR notation (e.g., 109.41.113.107/32)."
  }
}

variable "base_tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default = {
    CostCenter  = "AzureSponsorship"
    Owner       = "Group_5"
    Product     = "WebServe_Solutions"
    Environment = "Prod"
    ManagedBy   = "Terraform"
  }
}

variable "identity_names" {
  description = "Names for user-assigned identities."
  type = object({
    backup = string
    dcr    = string
    log    = string
  })
  default = {
    backup = "id-wss-bkb-sec-1"
    dcr    = "id-wss-vmss-dcr-sec-1"
    log    = "id-wss-log-sec-1"
  }
}

variable "key_vault_settings" {
  description = "Configuration for Key Vault and stored secrets."
  type = object({
    name                       = string
    sku_name                   = string
    soft_delete_retention_days = number
    rbac_authorization_enabled = bool
    diagnostics_name           = string
    purpose_tag                = string
    network_acls = object({
      bypass         = string
      default_action = string
    })
    secrets_officer_role_name      = string
    certificates_officer_role_name = string
    secrets = object({
      admin_username_name         = string
      admin_password_name         = string
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
  default = {
    name                       = "kv-wss-sec-1" # ***
    sku_name                   = "standard"
    soft_delete_retention_days = 7
    rbac_authorization_enabled = true
    diagnostics_name           = "kv-diagnostics"
    purpose_tag                = "VM-Credentials"
    network_acls = {
      bypass         = "AzureServices"
      default_action = "Allow"
    }
    secrets_officer_role_name      = "Key Vault Secrets Officer"
    certificates_officer_role_name = "Key Vault Certificates Officer"
    secrets = {
      admin_username_name         = "vm-admin-username"
      admin_password_name         = "vm-admin-password"
      admin_password_content_type = "password"
    }
    password_policy = {
      length           = 24
      special          = true
      override_special = "!#$%&*()-_=+[]{}<>:?"
      min_lower        = 2
      min_upper        = 2
      min_numeric      = 2
      min_special      = 2
    }
  }
}

variable "monitoring_settings" {
  description = "Settings for logging and monitoring components."
  type = object({
    log_analytics = object({
      name              = string
      sku               = string
      retention_in_days = number
    })
    storage_account = object({
      name                             = string
      account_tier                     = string
      account_replication_type         = string
      access_tier                      = string
      min_tls_version                  = string
      allow_nested_items_to_be_public  = bool
      public_network_access_enabled    = bool
      network_rules = object({
        default_action = string
        bypass         = list(string)
        ip_rules       = list(string)
      })
    })
    storage_role_name           = string
    metrics_publisher_role_name = string
    dcr = object({
      name              = string
      destination_name  = string
      data_flow_streams = list(string)
      performance_counters = object({
        streams                       = list(string)
        sampling_frequency_in_seconds = number
        counter_specifiers            = list(string)
        name                          = string
      })
      event_log_name   = string
      event_log_queries = list(string)
      iis_logs = object({
        streams         = list(string)
        name            = string
        log_directories = list(string)
      })
    })
    storage_management_policy = object({
      rule_name              = string
      prefix_match           = list(string)
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
  default = {
    log_analytics = {
      name              = "log-wss-sec-2" # ***
      sku               = "PerGB2018"
      retention_in_days = 30
    }
    storage_account = {
      name                             = "stlogbckwsssec1"
      account_tier                     = "Standard"
      account_replication_type         = "LRS"
      access_tier                      = "Hot"
      min_tls_version                  = "TLS1_2"
      allow_nested_items_to_be_public  = false
      public_network_access_enabled    = true
      network_rules = {
        default_action = "Deny"
        bypass         = ["AzureServices"]
        ip_rules       = ["2.212.99.105"]
      }
    }
    storage_role_name           = "Storage Blob Data Contributor"
    metrics_publisher_role_name = "Monitoring Metrics Publisher"
    dcr = {
      name             = "dcr-vmss-wss-1"
      destination_name = "law-destination"
      data_flow_streams = [
        "Microsoft-InsightsMetrics",
        "Microsoft-Event",
        "Microsoft-Perf"
      ]
      performance_counters = {
        streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
        sampling_frequency_in_seconds = 60
        counter_specifiers = [
          "\\Processor Information(_Total)\\% Processor Time",
          "\\Memory\\Available Bytes",
          "\\Memory\\% Committed Bytes In Use",
          "\\LogicalDisk(_Total)\\% Disk Time",
          "\\LogicalDisk(_Total)\\Free Megabytes",
          "\\LogicalDisk(_Total)\\% Free Space"
        ]
        name = "perf-counters"
      }
      event_log_name   = "event-logs"
      event_log_queries = [
        "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
        "System!*[System[(Level=1 or Level=2 or Level=3)]]"
      ]
      iis_logs = {
        streams         = ["Microsoft-W3CIISLog"]
        name            = "iisLogsDataSource"
        log_directories = ["C:\\inetpub\\logs\\LogFiles\\W3SVC1\\u_extend1.log"]
      }
    }
    storage_management_policy = {
      rule_name              = "log-lifecycle"
      prefix_match           = ["insights-logs/"]
      tier_to_cool_after_days    = 30
      tier_to_archive_after_days = 180
    }
    linked_storage_data_source_type = "CustomLogs"
    data_export = {
      name        = "export-specific-tables"
      table_names = [
        "Heartbeat",
        "Event",
        "Perf",
        "Usage",
        "SecurityEvent",
        "AzureActivity",
        "AppServiceHTTPLogs"
      ]
      enabled = true
    }
  }
}

variable "network_settings" {
  description = "Network layout including ASGs, NSGs, and subnets."
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
          name                  = string
          priority              = number
          direction             = string
          protocol              = string
          source_port_range     = string
          destination_port_range = string
        })
        apps_allow_https_from_mgmt = object({
          name                  = string
          priority              = number
          direction             = string
          protocol              = string
          source_port_range     = string
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
          name                    = string
          priority                = number
          direction               = string
          protocol                = string
          source_port_range       = string
          destination_port_range  = string
          source_address_prefix   = string
          destination_address_prefix = string
        })
        mgmt_allow_rdp_from_specific_ip = object({
          name                  = string
          priority              = number
          direction             = string
          protocol              = string
          source_port_range     = string
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
        name                                      = string
        address_prefixes                          = list(string)
        private_endpoint_network_policies         = string
        private_link_service_network_policies_enabled = bool
      })
      mgmt = object({
        name                                      = string
        address_prefixes                          = list(string)
        private_endpoint_network_policies         = string
        private_link_service_network_policies_enabled = bool
      })
    })
  })
  default = {
    asg = {
      web = {
        name       = "asg-web-wss-sec-1"
        extra_tags = { Tier = "web", Role = "application-and-load-balanced" }
      }
      mgmt = {
        name       = "asg-mgmt-wss-sec-1"
        extra_tags = { Tier = "management", Role = "administration" }
      }
    }
    nsg = {
      apps = {
        name             = "nsg-wss-sec-1"
        diagnostics_name = "nsg-apps-diagnostics"
      }
      mgmt = {
        name             = "nsg-mgmt-wss-sec-1"
        diagnostics_name = "nsg-mgmt-diagnostics"
      }
      rules = {
        apps_allow_rdp_from_mgmt = {
          name                  = "AllowRDPFromMgmt"
          priority              = 300
          direction             = "Inbound"
          protocol              = "Tcp"
          source_port_range     = "*"
          destination_port_range = "3389"
        }
        apps_allow_https_from_mgmt = {
          name                  = "AllowHttpsFromMngmt"
          priority              = 310
          direction             = "Inbound"
          protocol              = "Tcp"
          source_port_range     = "*"
          destination_port_range = "443"
        }
        apps_allow_https_from_internet = {
          name                  = "AllowHTTPSFromInternet"
          priority              = 250
          direction             = "Inbound"
          protocol              = "Tcp"
          source_port_range     = "*"
          destination_port_range = "443"
          source_address_prefix = "Internet"
        }
        apps_allow_health_probe = {
          name                    = "AllowAzureLoadBalancerInbound"
          priority                = 200
          direction               = "Inbound"
          protocol                = "*"
          source_port_range       = "*"
          destination_port_range  = "*"
          source_address_prefix   = "AzureLoadBalancer"
          destination_address_prefix = "*"
        }
        mgmt_allow_rdp_from_specific_ip = {
          name                  = "AllowRDPFromSpecificIP"
          priority              = 300
          direction             = "Inbound"
          protocol              = "Tcp"
          source_port_range     = "*"
          destination_port_range = "3389"
        }
      }
    }
    vnet = {
      name          = "vnet-wss-sec-1"
      address_space = ["10.100.0.0/16"]
    }
    subnets = {
      apps = {
        name                                      = "snet-app-wss-sec-1"
        address_prefixes                          = ["10.100.1.0/24"]
        private_endpoint_network_policies         = "Disabled"
        private_link_service_network_policies_enabled = true
      }
      mgmt = {
        name                                      = "snet-mngmnt-wss-sec-1"
        address_prefixes                          = ["10.100.0.0/24"]
        private_endpoint_network_policies         = "Disabled"
        private_link_service_network_policies_enabled = true
      }
    }
  }
}

variable "load_balancer_settings" {
  description = "Settings for the public IP and load balancer."
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
  default = {
    public_ip = {
      name                    = "pip-lb-wss-sec-1"
      allocation_method       = "Static"
      sku                     = "Standard"
      zones                   = ["1", "2", "3"]
      ip_version              = "IPv4"
      idle_timeout_in_minutes = 4
    }
    load_balancer = {
      name          = "lbi-wss-sec-1"
      sku           = "Standard"
      frontend_name = "PIP-LB"
    }
    backend_pools = {
      web_name  = "Pool-webs"
      mgmt_name = "backend_mgmt"
    }
    probes = {
      https = {
        name                = "HP-LB"
        protocol            = "Tcp"
        port                = 443
        interval_in_seconds = 5
        number_of_probes    = 1
      }
      rdp = {
        name                = "hp_3389"
        protocol            = "Tcp"
        port                = 3389
        interval_in_seconds = 5
        number_of_probes    = 1
      }
    }
    rules = {
      https = {
        name                  = "LB-rule"
        protocol              = "Tcp"
        frontend_port         = 443
        backend_port          = 443
        floating_ip_enabled   = false
        disable_outbound_snat = true
      }
      outbound = {
        name                     = "out-LB"
        protocol                 = "All"
        allocated_outbound_ports = 10000
        idle_timeout_in_minutes  = 4
      }
      rdp = {
        name                  = "Rule_3389"
        protocol              = "Tcp"
        frontend_port         = 3389
        backend_port          = 3389
        disable_outbound_snat = true
      }
    }
  }
}

variable "mgmt_vm_settings" {
  description = "Settings for the management virtual machine."
  type = object({
    nic_name              = string
    ip_configuration_name = string
    private_ip_allocation = string
    private_ip_version    = string
    vm_name               = string
    vm_size               = string
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
  default = {
    nic_name              = "nic-vm-mgmt-wss-sec-1"
    ip_configuration_name = "ipconfig1"
    private_ip_allocation = "Dynamic"
    private_ip_version    = "IPv4"
    vm_name               = "vm-mgt-wss-sec1"
    vm_size               = "Standard_D2as_v5"
    source_image = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
      name                 = "osdisk-vm-mgmt-wss-sec-001"
    }
    secure_boot_enabled = true
    vtpm_enabled        = true
  }
}

variable "vmss_sku" {
  description = "SKU for the VMSS."
  type        = string
  default     = "Standard_D2as_v5"
}

variable "vmss_zone1_min_instances" {
  description = "Minimum instances for VMSS zone 1."
  type        = number
  default     = 2
}

variable "vmss_zone1_max_instances" {
  description = "Maximum instances for VMSS zone 1."
  type        = number
  default     = 5
}

variable "autoscale_cpu_threshold_out" {
  description = "CPU threshold for scale-out."
  type        = number
  default     = 75
}

variable "autoscale_cpu_threshold_in" {
  description = "CPU threshold for scale-in."
  type        = number
  default     = 25
}

variable "business_hours_min_instances" {
  description = "Minimum instances during business hours."
  type        = number
  default     = 2
}

variable "business_hours_start" {
  description = "Start hour for business profile."
  type        = number
  default     = 8
}

variable "business_hours_end" {
  description = "End hour for business profile."
  type        = number
  default     = 18
}

variable "vmss_settings" {
  description = "Configuration for the VMSS and autoscale profiles."
  type = object({
    name                    = string
    zones                   = list(string)
    zone_balance            = bool
    upgrade_mode            = string
    network_interface_name  = string
    ip_configuration_name   = string
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
      name                        = string
      default_profile_name        = string
      business_hours_profile_name = string
      after_hours_profile_name    = string
      timezone                    = string
      business_days               = list(string)
      after_hours_max_instances   = number
      memory_threshold_bytes      = number
    })
  })
  default = {
    name                   = "vmss-app"
    zones                  = ["1"]
    zone_balance           = false
    upgrade_mode           = "Automatic"
    network_interface_name = "nic-vmss-zone1"
    ip_configuration_name  = "internal"
    source_image = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }
    extension = {
      name                       = "AzureMonitorWindowsAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorWindowsAgent"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
    }
    automatic_instance_repair = {
      enabled      = true
      grace_period = "PT30M"
    }
    dcra_name  = "dcra-vmss-zone1"
    extra_tags = { Zone = "1", Tier = "Web" }
    autoscale = {
      name                        = "autoscale-vmss-zone1"
      default_profile_name        = "defaultProfile"
      business_hours_profile_name = "businessHoursProfile"
      after_hours_profile_name    = "afterHoursProfile"
      timezone                    = "Central European Standard Time"
      business_days               = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      after_hours_max_instances   = 3
      memory_threshold_bytes      = 1073741824
    }
  }
}

variable "backup_settings" {
  description = "Settings for Recovery Services Vault and backup policy."
  type = object({
    vault_name                    = string
    vault_sku                     = string
    storage_mode_type             = string
    soft_delete_enabled           = bool
    public_network_access_enabled = bool
    immutability                  = string
    purpose_tag                   = string
    policy = object({
      name                         = string
      policy_type                  = string
      timezone                     = string
      instant_restore_retention_days = number
      backup = object({
        frequency     = string
        time          = string
        hour_interval = number
        hour_duration = number
      })
      retention_daily_count = number
    })
  })
  default = {
    vault_name                    = "rsv-wss-sec-2" # ***
    vault_sku                     = "Standard"
    storage_mode_type             = "LocallyRedundant"
    soft_delete_enabled           = false
    public_network_access_enabled = false
    immutability                  = "Disabled"
    purpose_tag                   = "Backup"
    policy = {
      name                         = "DefaultPolicies"
      policy_type                  = "V2"
      timezone                     = "UTC"
      instant_restore_retention_days = 2
      backup = {
        frequency     = "Hourly"
        time          = "08:00"
        hour_interval = 4
        hour_duration = 12
      }
      retention_daily_count = 30
    }
  }
}

variable "dns_settings" {
  description = "Settings for private DNS zone." 
  type = object({
    zone_name            = string
    vnet_link_name       = string
    registration_enabled = bool
    a_record_name        = string
    a_record_ttl         = number
    a_record_values      = list(string)
  })
  default = {
    zone_name            = "wss.local"
    vnet_link_name       = "localdns"
    registration_enabled = true
    a_record_name        = "pdns-rec-wss-mgmt"
    a_record_ttl         = 10
    a_record_values      = ["10.100.0.4"]
  }
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
  default = {
    storage = {
      name              = "pep-storageaccount-1"
      connection_name   = "pep-storageaccount-1"
      subresource_names = ["blob"]
    }
    rsv = {
      name              = "pep-recoveryvault-wss-1"
      connection_name   = "pep-recoveryvault-wss-1"
      subresource_names = ["AzureBackup"]
    }
  }
}

variable "autoscale_notification_emails" {
  description = "Emails for autoscale notifications."
  type        = list(string)
  default     = ["koosha.olad@gmail.com"]
}
