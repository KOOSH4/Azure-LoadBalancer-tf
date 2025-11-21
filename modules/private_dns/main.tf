resource "azurerm_private_dns_zone" "dns_zone" {
  name                = var.dns_settings.zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = var.dns_settings.vnet_link_name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = var.dns_settings.registration_enabled
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "dns_vm_mgmt" {
  name                = var.dns_settings.a_record_name
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = var.dns_settings.a_record_ttl
  records             = var.dns_settings.a_record_values
  tags                = var.tags
}
