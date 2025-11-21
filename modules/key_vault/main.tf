resource "random_password" "vm_admin_password" {
  length           = var.key_vault_settings.password_policy.length
  special          = var.key_vault_settings.password_policy.special
  override_special = var.key_vault_settings.password_policy.override_special
  min_lower        = var.key_vault_settings.password_policy.min_lower
  min_upper        = var.key_vault_settings.password_policy.min_upper
  min_numeric      = var.key_vault_settings.password_policy.min_numeric
  min_special      = var.key_vault_settings.password_policy.min_special
}

resource "azurerm_key_vault" "vm_credentials" {
  name                       = var.key_vault_settings.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = var.key_vault_settings.sku_name
  soft_delete_retention_days = var.key_vault_settings.soft_delete_retention_days
  rbac_authorization_enabled = var.key_vault_settings.rbac_authorization_enabled
  public_network_access_enabled = false


  network_acls {
    bypass         = var.key_vault_settings.network_acls.bypass
    default_action = var.key_vault_settings.network_acls.default_action
  }

  tags = merge(var.tags, {
    Purpose = var.key_vault_settings.purpose_tag
  })
}

resource "azurerm_monitor_diagnostic_setting" "kv_diagnostics" {
  name                       = var.key_vault_settings.diagnostics_name
  target_resource_id         = azurerm_key_vault.vm_credentials.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.vm_credentials.id
  role_definition_name = var.key_vault_settings.secrets_officer_role_name
  principal_id         = var.current_object_id
}

resource "azurerm_role_assignment" "kv_certificates_officer" {
  scope                = azurerm_key_vault.vm_credentials.id
  role_definition_name = var.key_vault_settings.certificates_officer_role_name
  principal_id         = var.current_object_id
}

resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = var.key_vault_settings.secrets.admin_username_name
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.vm_credentials.id

  depends_on = [azurerm_role_assignment.kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = var.key_vault_settings.secrets.admin_password_name
  value        = random_password.vm_admin_password.result
  key_vault_id = azurerm_key_vault.vm_credentials.id
  content_type = var.key_vault_settings.secrets.admin_password_content_type

  tags = merge(var.tags, {
    Purpose = "VM-Admin-Credentials"
  })

  depends_on = [azurerm_role_assignment.kv_secrets_officer]

  lifecycle {
    ignore_changes = [tags]
  }
}
