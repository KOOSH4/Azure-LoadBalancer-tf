resource "azurerm_application_security_group" "asg_web_tier" {
  name                = var.network_settings.asg.web.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, var.network_settings.asg.web.extra_tags)
}

resource "azurerm_application_security_group" "asg_mgmt_tier" {
  name                = var.network_settings.asg.mgmt.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, var.network_settings.asg.mgmt.extra_tags)
}

resource "azurerm_network_security_group" "nsg_sub_apps" {
  name                = var.network_settings.nsg.apps.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Purpose = "Application-Subnet-Security"
  })
}

resource "azurerm_network_security_group" "nsg_sub_mgmt" {
  name                = var.network_settings.nsg.mgmt.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Purpose = "Management-Subnet-Security"
  })
}

resource "azurerm_monitor_diagnostic_setting" "nsg_apps_diagnostics" {
  name                       = var.network_settings.nsg.apps.diagnostics_name
  target_resource_id         = azurerm_network_security_group.nsg_sub_apps.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg_mgmt_diagnostics" {
  name                       = var.network_settings.nsg.mgmt.diagnostics_name
  target_resource_id         = azurerm_network_security_group.nsg_sub_mgmt.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_network_security_rule" "apps_allow_rdp_from_mgmt" {
  name                                       = var.network_settings.nsg.rules.apps_allow_rdp_from_mgmt.name
  priority                                   = var.network_settings.nsg.rules.apps_allow_rdp_from_mgmt.priority
  direction                                  = var.network_settings.nsg.rules.apps_allow_rdp_from_mgmt.direction
  access                                     = "Allow"
  protocol                                   = var.network_settings.nsg.rules.apps_allow_rdp_from_mgmt.protocol
  source_port_range                          = var.network_settings.nsg.rules.apps_allow_rdp_from_mgmt.source_port_range
  destination_port_range                     = var.network_settings.nsg.rules.apps_allow_rdp_from_mgmt.destination_port_range
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
  name                                       = var.network_settings.nsg.rules.apps_allow_https_from_mgmt.name
  priority                                   = var.network_settings.nsg.rules.apps_allow_https_from_mgmt.priority
  direction                                  = var.network_settings.nsg.rules.apps_allow_https_from_mgmt.direction
  access                                     = "Allow"
  protocol                                   = var.network_settings.nsg.rules.apps_allow_https_from_mgmt.protocol
  source_port_range                          = var.network_settings.nsg.rules.apps_allow_https_from_mgmt.source_port_range
  destination_port_range                     = var.network_settings.nsg.rules.apps_allow_https_from_mgmt.destination_port_range
  source_application_security_group_ids      = [azurerm_application_security_group.asg_mgmt_tier.id]
  destination_application_security_group_ids = [azurerm_application_security_group.asg_web_tier.id]
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.nsg_sub_apps.name
}

resource "azurerm_network_security_rule" "apps_allow_https_from_internet" {
  name                                       = var.network_settings.nsg.rules.apps_allow_https_from_internet.name
  priority                                   = var.network_settings.nsg.rules.apps_allow_https_from_internet.priority
  direction                                  = var.network_settings.nsg.rules.apps_allow_https_from_internet.direction
  access                                     = "Allow"
  protocol                                   = var.network_settings.nsg.rules.apps_allow_https_from_internet.protocol
  source_port_range                          = var.network_settings.nsg.rules.apps_allow_https_from_internet.source_port_range
  destination_port_range                     = var.network_settings.nsg.rules.apps_allow_https_from_internet.destination_port_range
  source_address_prefix                      = var.network_settings.nsg.rules.apps_allow_https_from_internet.source_address_prefix
  destination_application_security_group_ids = [azurerm_application_security_group.asg_web_tier.id]
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.nsg_sub_apps.name

  depends_on = [
    azurerm_application_security_group.asg_web_tier,
    azurerm_network_security_group.nsg_sub_apps
  ]
}

resource "azurerm_network_security_rule" "apps_allow_health_probe" {
  name                        = var.network_settings.nsg.rules.apps_allow_health_probe.name
  priority                    = var.network_settings.nsg.rules.apps_allow_health_probe.priority
  direction                   = var.network_settings.nsg.rules.apps_allow_health_probe.direction
  access                      = "Allow"
  protocol                    = var.network_settings.nsg.rules.apps_allow_health_probe.protocol
  source_port_range           = var.network_settings.nsg.rules.apps_allow_health_probe.source_port_range
  destination_port_range      = var.network_settings.nsg.rules.apps_allow_health_probe.destination_port_range
  source_address_prefix       = var.network_settings.nsg.rules.apps_allow_health_probe.source_address_prefix
  destination_address_prefix  = var.network_settings.nsg.rules.apps_allow_health_probe.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sub_apps.name

  depends_on = [
    azurerm_network_security_group.nsg_sub_apps
  ]
}

resource "azurerm_network_security_rule" "mgmt_allow_rdp_from_specific_ip" {
  name                                       = var.network_settings.nsg.rules.mgmt_allow_rdp_from_specific_ip.name
  priority                                   = var.network_settings.nsg.rules.mgmt_allow_rdp_from_specific_ip.priority
  direction                                  = var.network_settings.nsg.rules.mgmt_allow_rdp_from_specific_ip.direction
  access                                     = "Allow"
  protocol                                   = var.network_settings.nsg.rules.mgmt_allow_rdp_from_specific_ip.protocol
  source_port_range                          = var.network_settings.nsg.rules.mgmt_allow_rdp_from_specific_ip.source_port_range
  destination_port_range                     = var.network_settings.nsg.rules.mgmt_allow_rdp_from_specific_ip.destination_port_range
  source_address_prefix                      = var.allowed_rdp_cidr
  destination_application_security_group_ids = [azurerm_application_security_group.asg_mgmt_tier.id]
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.nsg_sub_mgmt.name

  depends_on = [
    azurerm_application_security_group.asg_mgmt_tier,
    azurerm_network_security_group.nsg_sub_mgmt
  ]
}

resource "azurerm_virtual_network" "vnet_shared" {
  name                = var.network_settings.vnet.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.network_settings.vnet.address_space

  tags = var.tags
}

resource "azurerm_subnet" "sub_apps" {
  name                 = var.network_settings.subnets.apps.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_shared.name
  address_prefixes     = var.network_settings.subnets.apps.address_prefixes

  private_endpoint_network_policies             = var.network_settings.subnets.apps.private_endpoint_network_policies
  private_link_service_network_policies_enabled = var.network_settings.subnets.apps.private_link_service_network_policies_enabled

  depends_on = [azurerm_virtual_network.vnet_shared]
}

resource "azurerm_subnet" "sub_mgmt" {
  name                 = var.network_settings.subnets.mgmt.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_shared.name
  address_prefixes     = var.network_settings.subnets.mgmt.address_prefixes

  private_endpoint_network_policies             = var.network_settings.subnets.mgmt.private_endpoint_network_policies
  private_link_service_network_policies_enabled = var.network_settings.subnets.mgmt.private_link_service_network_policies_enabled

  depends_on = [azurerm_virtual_network.vnet_shared]
}

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
