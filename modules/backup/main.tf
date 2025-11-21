resource "azurerm_recovery_services_vault" "rsv" {
  name                          = var.backup_settings.vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.backup_settings.vault_sku
  storage_mode_type             = var.backup_settings.storage_mode_type
  soft_delete_enabled           = var.backup_settings.soft_delete_enabled
  public_network_access_enabled = var.backup_settings.public_network_access_enabled
  immutability                  = var.backup_settings.immutability

  tags = merge(var.tags, {
    Purpose = var.backup_settings.purpose_tag
  })
}

resource "azurerm_backup_policy_vm" "policy_daily" {
  name                = var.backup_settings.policy.name
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.rsv.name
  policy_type         = var.backup_settings.policy.policy_type
  timezone            = var.backup_settings.policy.timezone

  instant_restore_retention_days = var.backup_settings.policy.instant_restore_retention_days

  backup {
    frequency     = var.backup_settings.policy.backup.frequency
    time          = var.backup_settings.policy.backup.time
    hour_interval = var.backup_settings.policy.backup.hour_interval
    hour_duration = var.backup_settings.policy.backup.hour_duration
  }

  retention_daily {
    count = var.backup_settings.policy.retention_daily_count
  }
}
