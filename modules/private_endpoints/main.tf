resource "azurerm_private_endpoint" "pep_storage" {
  name                = var.private_endpoint_settings.storage.name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = var.private_endpoint_settings.storage.connection_name
    private_connection_resource_id = var.storage_account_id
    is_manual_connection           = false
    subresource_names              = var.private_endpoint_settings.storage.subresource_names
  }
}

resource "azurerm_private_endpoint" "pep_rsv" {
  name                = var.private_endpoint_settings.rsv.name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = var.private_endpoint_settings.rsv.connection_name
    private_connection_resource_id = var.recovery_services_vault_id
    is_manual_connection           = false
    subresource_names              = var.private_endpoint_settings.rsv.subresource_names
  }
}
