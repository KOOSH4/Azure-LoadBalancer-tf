# ===========================================================================
# MAIN.TF
# ===========================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.51.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = false
    }
  }
  use_oidc        = true
  subscription_id = var.subscription_id
  client_id       = var.client_id
  tenant_id       = var.tenant_id
}

# ===========================================================================
# LOCAL VARIABLES FOR COMMON TAGS
# ===========================================================================

locals {
  common_tags = {
    CostCenter  = "AzureSponsorship"
    Owner       = "Group_5"
    Product     = "WebServe_Solutions"
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Location    = var.location
  }
}

# ===========================================================================
# DATA SOURCES
# ===========================================================================

data "azurerm_client_config" "current" {}

# ============================================================================
# RANDOM PASSWORD GENERATION
# ============================================================================

resource "random_password" "vm_admin_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# ============================================================================
# User Assigned Identities
# ============================================================================


resource "azurerm_user_assigned_identity" "id_backup" {
  location            = var.location
  name                = "id-wss-bkb-sec-1"
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
}

resource "azurerm_user_assigned_identity" "id_dcr" {
  location            = var.location
  name                = "id-wss-vmss-dcr-sec-1"
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
}
# Allow the VMSS System Identity to publish data to the DCR
resource "azurerm_role_assignment" "vmss_metrics_publisher" {
  scope                = azurerm_monitor_data_collection_rule.dcr_vmss.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.identity[0].principal_id
}

resource "azurerm_user_assigned_identity" "id_log" {
  location            = var.location
  name                = "id-wss-log-sec-1"
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "law_storage_contributor" {
  scope                = azurerm_storage_account.stblc.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.id_log.principal_id
}
# ============================================================================
# Private Endpoints
# ============================================================================

# Storage Private Endpoint
resource "azurerm_private_endpoint" "pep_storage" {
  name                = "pep-storageaccount-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.sub_apps.id

  private_service_connection {
    name                           = "pep-storageaccount-01"
    private_connection_resource_id = azurerm_storage_account.stblc.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  /*   private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_blob.id]
  } */
}

# RSV Private Endpoint
resource "azurerm_private_endpoint" "pep_rsv" {
  name                = "pep-recoveryvault-wss-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.sub_apps.id

  private_service_connection {
    name                           = "pep-recoveryvault-wss-01"
    private_connection_resource_id = azurerm_recovery_services_vault.rsv.id
    is_manual_connection           = false
    subresource_names              = ["AzureBackup"]
  }

  /*   private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_backup.id]
  } */
}
# ============================================================================
# KEY VAULT ***
# ============================================================================

resource "azurerm_key_vault" "vm_credentials" {
  name                       = "kv-wss-sec-016"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  rbac_authorization_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = merge(local.common_tags, {
    Purpose = "VM-Credentials"
  })
}

# ============================================================================
# KEY VAULT DIAGNOSTICS
# ============================================================================

resource "azurerm_monitor_diagnostic_setting" "kv_diagnostics" {
  name                       = "kv-diagnostics"
  target_resource_id         = azurerm_key_vault.vm_credentials.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  enabled_metric {
    category = "AllMetrics"

  }

  depends_on = [azurerm_log_analytics_workspace.law]
}

# ============================================================================
# KEY VAULT RBAC
# ============================================================================

resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.vm_credentials.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "kv_certificates_officer" {
  scope                = azurerm_key_vault.vm_credentials.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ============================================================================
# KEY VAULT SECRETS
# ============================================================================

resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "vm-admin-username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.vm_credentials.id

  depends_on = [azurerm_role_assignment.kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = random_password.vm_admin_password.result
  key_vault_id = azurerm_key_vault.vm_credentials.id
  content_type = "password"

  tags = merge(local.common_tags, {
    Purpose = "VM-Admin-Credentials"
  })

  depends_on = [azurerm_role_assignment.kv_secrets_officer]

  lifecycle {
    ignore_changes = [tags]
  }
}

# ============================================================================
# APPLICATION SECURITY GROUPS
# ============================================================================

resource "azurerm_application_security_group" "asg_web_tier" {
  name                = "asg-web-wss-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(local.common_tags, {
    Tier = "web"
    Role = "application-and-load-balanced"
  })
}

resource "azurerm_application_security_group" "asg_mgmt_tier" {
  name                = "asg-mgmt-wss-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(local.common_tags, {
    Tier = "management"
    Role = "administration"
  })
}

# VMSS NICs will only use asg_web_tier

# ===========================================================================
# NETWORK SECURITY GROUPS
# ===========================================================================

resource "azurerm_network_security_group" "nsg_sub_apps" {
  name                = "nsg-wss-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(local.common_tags, {
    Purpose = "Application-Subnet-Security"
  })
}

resource "azurerm_network_security_group" "nsg_sub_mgmt" {
  name                = "nsg-mgmt-wss-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(local.common_tags, {
    Purpose = "Management-Subnet-Security"
  })
}

# ============================================================================
# NSG DIAGNOSTICS
# ============================================================================

resource "azurerm_monitor_diagnostic_setting" "nsg_apps_diagnostics" {
  name                       = "nsg-apps-diagnostics"
  target_resource_id         = azurerm_network_security_group.nsg_sub_apps.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }

  depends_on = [azurerm_log_analytics_workspace.law]
}

resource "azurerm_monitor_diagnostic_setting" "nsg_mgmt_diagnostics" {
  name                       = "nsg-mgmt-diagnostics"
  target_resource_id         = azurerm_network_security_group.nsg_sub_mgmt.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }

  depends_on = [azurerm_log_analytics_workspace.law]
}

# ============================================================================
# NSG RULES - APPLICATION SUBNET
# ============================================================================

resource "azurerm_network_security_rule" "apps_allow_rdp_from_mgmt" {
  name                                       = "AllowRDPFromMgmt"
  priority                                   = 300
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "3389"
  source_application_security_group_ids      = [azurerm_application_security_group.asg_mgmt_tier.id]
  destination_application_security_group_ids = [azurerm_application_security_group.asg_web_tier.id]
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.nsg_sub_apps.name

  depends_on = [
    azurerm_application_security_group.asg_mgmt_tier,
    azurerm_application_security_group.asg_web_tier,
    azurerm_network_security_group.nsg_sub_apps
  ]
}

resource "azurerm_network_security_rule" "apps_allow_https_from_mgmt" {
  name                                       = "AllowHttpsFromMngmt"
  priority                                   = 310
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "443"
  source_application_security_group_ids      = [azurerm_application_security_group.asg_mgmt_tier.id]
  destination_application_security_group_ids = [azurerm_application_security_group.asg_web_tier.id]
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.nsg_sub_apps.name
}

resource "azurerm_network_security_rule" "apps_allow_https_from_internet" {
  name                                       = "AllowHTTPSFromInternet"
  priority                                   = 250
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "443"
  source_address_prefix                      = "Internet"
  destination_application_security_group_ids = [azurerm_application_security_group.asg_web_tier.id]
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.nsg_sub_apps.name

  depends_on = [
    azurerm_application_security_group.asg_web_tier,
    azurerm_network_security_group.nsg_sub_apps
  ]
}

# ============================================================================
# NSG RULES - MANAGEMENT SUBNET
# ============================================================================

resource "azurerm_network_security_rule" "mgmt_allow_rdp_from_specific_ip" {
  name                                       = "AllowRDPFromSpecificIP"
  priority                                   = 300
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "3389"
  source_address_prefix                      = var.allowed_rdp_ip
  destination_application_security_group_ids = [azurerm_application_security_group.asg_mgmt_tier.id]
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.nsg_sub_mgmt.name

  depends_on = [
    azurerm_application_security_group.asg_mgmt_tier,
    azurerm_network_security_group.nsg_sub_mgmt
  ]
}
resource "azurerm_network_security_rule" "apps_allow_health_probe" {
  name                        = "AllowAzureLoadBalancerInbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sub_apps.name

  depends_on = [
    azurerm_network_security_group.nsg_sub_apps
  ]
}
# ============================================================================
# VIRTUAL NETWORK AND SUBNETS
# ============================================================================

resource "azurerm_virtual_network" "vnet_shared" {
  name                = "vnet-wss-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.100.0.0/16"]

  tags = local.common_tags
}

resource "azurerm_subnet" "sub_apps" {
  name                 = "snet-app-wss-lab-sec-001"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_shared.name
  address_prefixes     = ["10.100.1.0/24"]

  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true

  depends_on = [azurerm_virtual_network.vnet_shared]
}

resource "azurerm_subnet" "sub_mgmt" {
  name                 = "snet-mngmnt-wss-lab-sec-002"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_shared.name
  address_prefixes     = ["10.100.0.0/24"]

  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true

  depends_on = [azurerm_virtual_network.vnet_shared]
}

# ============================================================================
# SUBNET NSG ASSOCIATIONS
# ============================================================================

resource "azurerm_subnet_network_security_group_association" "sub_apps_nsg" {
  subnet_id                 = azurerm_subnet.sub_apps.id
  network_security_group_id = azurerm_network_security_group.nsg_sub_apps.id

  depends_on = [
    azurerm_subnet.sub_apps,
    azurerm_network_security_group.nsg_sub_apps,
    azurerm_network_security_rule.apps_allow_rdp_from_mgmt,
    azurerm_network_security_rule.apps_allow_https_from_internet
  ]
}

resource "azurerm_subnet_network_security_group_association" "sub_mgmt_nsg" {
  subnet_id                 = azurerm_subnet.sub_mgmt.id
  network_security_group_id = azurerm_network_security_group.nsg_sub_mgmt.id

  depends_on = [
    azurerm_subnet.sub_mgmt,
    azurerm_network_security_group.nsg_sub_mgmt,
    azurerm_network_security_rule.mgmt_allow_rdp_from_specific_ip
  ]
}
# delete AllowHTTPSFromInternet
# ============================================================================
# LOG ANALYTICS WORKSPACE ***
# ============================================================================

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-wss-sec-016"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.id_log.id
    ]
  }

  tags = merge(local.common_tags, {
    Purpose = "Logging"
  })
}

# ============================================================================
# STORAGE ACCOUNT FOR LOG EXPORT
# ============================================================================

resource "azurerm_storage_account" "stblc" {
  name                     = "stblcwsslabsec001"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true


  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = ["2.212.99.105"]
  }

  tags = merge(local.common_tags, {
    Purpose = "Log-Storage"
  })
}

# ============================================================================
# STORAGE ACCOUNT DIAGNOSTICS ***
# ============================================================================

/* resource "azurerm_monitor_diagnostic_setting" "storage_diagnostics" {
  name                       = "storage-diagnostics1"
  target_resource_id         = azurerm_storage_account.stblc.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "Transaction"

  }

  enabled_metric {
    category = "Capacity"

  }
} */

# ============================================================================
# DATA COLLECTION RULE (DCR)
# ============================================================================

resource "azurerm_monitor_data_collection_rule" "dcr_vmss" {
  name                = "dcr-vmss-wss-001"
  resource_group_name = var.resource_group_name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
      name                  = "law-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics", "Microsoft-Event", "Microsoft-Perf"]
    destinations = ["law-destination"]
  }

  data_sources {
    performance_counter {
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

    windows_event_log {
      streams = ["Microsoft-Event"]
      x_path_queries = [
        "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
        "System!*[System[(Level=1 or Level=2 or Level=3)]]"
      ]
      name = "event-logs"
    }

    # --- NEW SECTION: Add IIS Log Source ---
    iis_log {
      streams = ["Microsoft-W3CIISLog"]
      name    = "iisLogsDataSource"
      # This path was found in the export
      log_directories = ["C:\\inetpub\\logs\\LogFiles\\W3SVC1\\u_extend1.log"]
    }
  }

  depends_on = [azurerm_log_analytics_workspace.law]
}
# ============================================================================
# PUBLIC IP ADDRESSES
# ============================================================================

resource "azurerm_public_ip" "pip_lb" {
  name                    = "pip-lb-wss-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  zones                   = ["1", "2", "3"]
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4

  tags = local.common_tags
}

# ============================================================================
# LOAD BALANCER
# ============================================================================

resource "azurerm_lb" "lb" {
  name                = "lbi-wss-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PIP-LB"
    public_ip_address_id = azurerm_public_ip.pip_lb.id
  }

  tags = local.common_tags

  depends_on = [azurerm_public_ip.pip_lb]
}

# ============================================================================
# LOAD BALANCER DIAGNOSTICS ***
# ============================================================================

/* resource "azurerm_monitor_diagnostic_setting" "lb_diagnostics" {
  name                       = "lb-diagnostics"
  target_resource_id         = azurerm_lb.lb.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id



  enabled_metric {
    category = "AllMetrics"

  }
} */

resource "azurerm_lb_backend_address_pool" "pool_webs" {
  name            = "Pool-webs"
  loadbalancer_id = azurerm_lb.lb.id

  depends_on = [azurerm_lb.lb]
}

resource "azurerm_lb_probe" "hp_lb" {
  name                = "HP-LB"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 1

  depends_on = [azurerm_lb.lb]
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "LB-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "PIP-LB"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool_webs.id]
  probe_id                       = azurerm_lb_probe.hp_lb.id
  floating_ip_enabled            = false
  disable_outbound_snat          = true

  depends_on = [
    azurerm_lb_backend_address_pool.pool_webs,
    azurerm_lb_probe.hp_lb
  ]
}

resource "azurerm_lb_outbound_rule" "out_lb" {
  name                     = "out-LB"
  loadbalancer_id          = azurerm_lb.lb.id
  protocol                 = "All"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.pool_webs.id
  allocated_outbound_ports = 10000
  idle_timeout_in_minutes  = 4

  frontend_ip_configuration {
    name = "PIP-LB"
  }

  depends_on = [
    azurerm_lb_backend_address_pool.pool_webs,
    azurerm_lb_rule.lb_rule
  ]
}

resource "azurerm_lb_backend_address_pool" "pool_mgmt" {
  name            = "backend_mgmt"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "hp_3389" {
  name                = "hp_3389"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  port                = 3389
  interval_in_seconds = 5
  number_of_probes    = 1
}

resource "azurerm_lb_rule" "rule_3389" {
  name                           = "Rule_3389"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "PIP-LB"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool_mgmt.id]
  probe_id                       = azurerm_lb_probe.hp_3389.id
  disable_outbound_snat          = true
}
# ============================================================================
# MANAGEMENT VM
# ============================================================================

resource "azurerm_network_interface" "nic_mgmt" {
  name                = "nic-vm-mgmt-wss-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub_mgmt.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

  tags = local.common_tags

  depends_on = [azurerm_subnet.sub_mgmt]
}


resource "azurerm_network_interface_backend_address_pool_association" "nic_mgmt_lb" {
  network_interface_id    = azurerm_network_interface.nic_mgmt.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool_mgmt.id
}


resource "azurerm_network_interface_application_security_group_association" "nic_mgmt_asg" {
  network_interface_id          = azurerm_network_interface.nic_mgmt.id
  application_security_group_id = azurerm_application_security_group.asg_mgmt_tier.id

  depends_on = [
    azurerm_network_interface.nic_mgmt,
    azurerm_application_security_group.asg_mgmt_tier
  ]
}

resource "azurerm_windows_virtual_machine" "vm_mgmt" {
  name                  = "vm-mgmt-wss-sec"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_D2as_v5"
  admin_username        = azurerm_key_vault_secret.vm_admin_username.value
  admin_password        = azurerm_key_vault_secret.vm_admin_password.value
  network_interface_ids = [azurerm_network_interface.nic_mgmt.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-vm-mgmt-wss-sec-001"
  }

  secure_boot_enabled = true
  vtpm_enabled        = true

  tags = merge(local.common_tags, {
    Role = "Management"
  })

  depends_on = [
    azurerm_network_interface.nic_mgmt,
    azurerm_key_vault_secret.vm_admin_password
  ]
}

# ============================================================================
# VMSS - ZONE 1
# ============================================================================

resource "azurerm_windows_virtual_machine_scale_set" "vmss_web_zone1" {
  name                = "vmss-app1"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.vmss_sku
  instances           = var.vmss_zone1_min_instances
  admin_username      = azurerm_key_vault_secret.vm_admin_username.value
  admin_password      = azurerm_key_vault_secret.vm_admin_password.value

  zones        = ["1"]
  zone_balance = false

  upgrade_mode    = "Automatic"
  health_probe_id = azurerm_lb_probe.hp_lb.id

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.id_backup.id,
      azurerm_user_assigned_identity.id_dcr.id
    ]
  }

  network_interface {
    name    = "nic-vmss-zone1"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.sub_apps.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.pool_webs.id]


      application_security_group_ids = [
        azurerm_application_security_group.asg_web_tier.id
      ]
    }
  }
  extension {
    name                       = "AzureMonitorWindowsAgent"
    publisher                  = "Microsoft.Azure.Monitor"
    type                       = "AzureMonitorWindowsAgent"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
  }
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT30M"
  }

  tags = merge(local.common_tags, {
    Zone = "1"
    Tier = "Web"
  })

  depends_on = [
    azurerm_subnet.sub_apps,
    azurerm_lb_backend_address_pool.pool_webs,
    azurerm_lb_probe.hp_lb,
    azurerm_application_security_group.asg_web_tier,
    azurerm_key_vault_secret.vm_admin_password,
    azurerm_lb_rule.lb_rule
  ]
}

# ============================================================================
# VMSS DIAGNOSTICS - ZONE 1 ***
# ============================================================================

/* resource "azurerm_monitor_diagnostic_setting" "vmss_zone1_diagnostics" {
  name                       = "vmss-zone1-diagnostics1"
  target_resource_id         = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"

  }
} */

# ============================================================================
# DCR ASSOCIATIONS
# ============================================================================

resource "azurerm_monitor_data_collection_rule_association" "dcra_zone1" {
  name                    = "dcra-vmss-zone1"
  target_resource_id      = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_vmss.id
}

# ============================================================================
# AUTOSCALE SETTINGS - ZONE 1
# ============================================================================

resource "azurerm_monitor_autoscale_setting" "vmss_zone1_autoscale" {
  name                = "autoscale-vmss-zone1"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id

  profile {
    name = "defaultProfile"

    capacity {
      default = var.vmss_zone1_min_instances
      minimum = var.vmss_zone1_min_instances
      maximum = var.vmss_zone1_max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.autoscale_cpu_threshold_out
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.autoscale_cpu_threshold_in
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  profile {
    name = "businessHoursProfile"

    capacity {
      default = var.business_hours_min_instances
      minimum = var.business_hours_min_instances
      maximum = var.vmss_zone1_max_instances
    }

    recurrence {
      timezone = "Central European Standard Time"
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [var.business_hours_start]
      minutes  = [0]
    }
  }

  profile {
    name = "afterHoursProfile"

    capacity {
      default = var.vmss_zone1_min_instances
      minimum = var.vmss_zone1_min_instances
      maximum = 3
    }

    recurrence {
      timezone = "Central European Standard Time"
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [var.business_hours_end]
      minutes  = [0]
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      custom_emails                         = var.autoscale_notification_emails
    }
  }

  tags = local.common_tags

  depends_on = [azurerm_windows_virtual_machine_scale_set.vmss_web_zone1]
}



# ============================================================================
# BACKUP VAULT (Azure Backup Vault for modern workloads)
# ============================================================================

resource "azurerm_data_protection_backup_vault" "backup_vault" {
  name                = "bvault-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"
  soft_delete         = "Off"



}

# ============================================================================
# BACKUP VAULT DIAGNOSTICS ***
# ============================================================================

/* resource "azurerm_monitor_diagnostic_setting" "backup_vault_diagnostics" {
  name                       = "backup-vault-diagnostics1"
  target_resource_id         = azurerm_data_protection_backup_vault.backup_vault.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "CoreAzureBackup"
  }

  enabled_log {
    category = "AddonAzureBackupJobs"
  }


  enabled_metric {
    category = "Health"

  }
  

  depends_on = [azurerm_log_analytics_workspace.law]
} */

# ============================================================================
# LIFECYCLE MANAGEMENT POLICY
# ============================================================================

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.stblc.id

  rule {
    name    = "log-lifecycle"
    enabled = true

    filters {
      prefix_match = ["insights-logs/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 180
      }
    }
  }
}

# ============================================================================
# LINKED STORAGE ACCOUNT
# ============================================================================

resource "azurerm_log_analytics_linked_storage_account" "law_storage" {
  data_source_type      = "CustomLogs"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.law.id
  storage_account_ids   = [azurerm_storage_account.stblc.id]
}

# ============================================================================
# DATA EXPORT RULES
# ============================================================================

resource "azurerm_log_analytics_data_export_rule" "export_logs" {
  name                    = "export-specific-tables"
  resource_group_name     = var.resource_group_name
  workspace_resource_id   = azurerm_log_analytics_workspace.law.id
  destination_resource_id = azurerm_storage_account.stblc.id

  # You MUST list specific tables. Wildcard "*" is not supported.
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

  # This relies on the Role Assignment existing first
  depends_on = [
    azurerm_role_assignment.law_storage_contributor
  ]
}
# ============================================================================
# Recovery Services Vault (RSV) & Backup Policy ***
# ============================================================================
resource "azurerm_recovery_services_vault" "rsv" {
  name                          = "rsv-wss-sec-016"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Standard"
  storage_mode_type             = "LocallyRedundant"
  soft_delete_enabled           = false
  public_network_access_enabled = false
  immutability                  = "Disabled"
  tags = merge(local.common_tags, {
    Purpose = "Backup"
  })
}

resource "azurerm_backup_policy_vm" "policy_daily" {
  name                = "DefaultPolicy"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.rsv.name
  policy_type         = "V2"
  timezone            = "UTC"

  instant_restore_retention_days = 2


  backup {
    frequency     = "Hourly"
    time          = "08:00"
    hour_interval = 4
    hour_duration = 12
  }

  retention_daily {
    count = 30
  }

}
# ============================================================================
# PRIVATE DNS ZONE
# ============================================================================

resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "wss.local"
  resource_group_name = var.resource_group_name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = "localdns"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet_shared.id
  registration_enabled  = true

  tags = local.common_tags

  depends_on = [
    azurerm_private_dns_zone.dns_zone,
    azurerm_virtual_network.vnet_shared
  ]
}



# ============================================================================
# PRIVATE DNS A RECORDS
# ============================================================================

resource "azurerm_private_dns_a_record" "dns_vm_mgmt" {
  name                = "pdns-rec-wss-mgmt"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = 10
  records             = ["10.100.0.4"]

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone.dns_zone]
}