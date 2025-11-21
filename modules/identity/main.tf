resource "azurerm_user_assigned_identity" "backup" {
  name                = var.identity_names.backup
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "dcr" {
  name                = var.identity_names.dcr
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "log" {
  name                = var.identity_names.log
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
