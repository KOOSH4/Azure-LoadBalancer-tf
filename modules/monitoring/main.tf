resource "azurerm_log_analytics_workspace" "law" {
  name                = var.monitoring_settings.log_analytics.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.monitoring_settings.log_analytics.sku
  retention_in_days   = var.monitoring_settings.log_analytics.retention_in_days

  identity {
    type = "UserAssigned"
    identity_ids = [
      var.log_identity_id
    ]
  }

  tags = merge(var.tags, {
    Purpose = "Logging"
  })
}

resource "azurerm_storage_account" "stblc" {
  name                     = var.monitoring_settings.storage_account.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.monitoring_settings.storage_account.account_tier
  account_replication_type = var.monitoring_settings.storage_account.account_replication_type
  access_tier              = var.monitoring_settings.storage_account.access_tier

  min_tls_version                 = var.monitoring_settings.storage_account.min_tls_version
  allow_nested_items_to_be_public = var.monitoring_settings.storage_account.allow_nested_items_to_be_public
  public_network_access_enabled   = var.monitoring_settings.storage_account.public_network_access_enabled

  network_rules {
    default_action = var.monitoring_settings.storage_account.network_rules.default_action
    bypass         = var.monitoring_settings.storage_account.network_rules.bypass
    ip_rules       = var.monitoring_settings.storage_account.network_rules.ip_rules
  }

  tags = merge(var.tags, {
    Purpose = "Log-Storage"
  })
}

resource "azurerm_role_assignment" "law_storage_contributor" {
  scope                = azurerm_storage_account.stblc.id
  role_definition_name = var.monitoring_settings.storage_role_name
  principal_id         = var.log_identity_principal_id
}

resource "azurerm_monitor_data_collection_rule" "dcr_vmss" {
  name                = var.monitoring_settings.dcr.name
  resource_group_name = var.resource_group_name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
      name                  = var.monitoring_settings.dcr.destination_name
    }
  }

  data_flow {
    streams      = var.monitoring_settings.dcr.data_flow_streams
    destinations = [var.monitoring_settings.dcr.destination_name]
  }

  data_sources {
    performance_counter {
      streams                       = var.monitoring_settings.dcr.performance_counters.streams
      sampling_frequency_in_seconds = var.monitoring_settings.dcr.performance_counters.sampling_frequency_in_seconds
      counter_specifiers            = var.monitoring_settings.dcr.performance_counters.counter_specifiers
      name                          = var.monitoring_settings.dcr.performance_counters.name
    }

    windows_event_log {
      streams        = ["Microsoft-Event"]
      x_path_queries = var.monitoring_settings.dcr.event_log_queries
      name           = var.monitoring_settings.dcr.event_log_name
    }

    iis_log {
      streams         = var.monitoring_settings.dcr.iis_logs.streams
      name            = var.monitoring_settings.dcr.iis_logs.name
      log_directories = var.monitoring_settings.dcr.iis_logs.log_directories
    }
  }

  depends_on = [azurerm_log_analytics_workspace.law]
}

resource "azurerm_role_assignment" "vmss_metrics_publisher" {
  scope                = azurerm_monitor_data_collection_rule.dcr_vmss.id
  role_definition_name = var.monitoring_settings.metrics_publisher_role_name
  principal_id         = var.metrics_publisher_principal_id
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.stblc.id

  rule {
    name    = var.monitoring_settings.storage_management_policy.rule_name
    enabled = true

    filters {
      prefix_match = var.monitoring_settings.storage_management_policy.prefix_match
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.monitoring_settings.storage_management_policy.tier_to_cool_after_days
        tier_to_archive_after_days_since_modification_greater_than = var.monitoring_settings.storage_management_policy.tier_to_archive_after_days
      }
    }
  }
}

resource "azurerm_log_analytics_linked_storage_account" "law_storage" {
  data_source_type      = var.monitoring_settings.linked_storage_data_source_type
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.law.id
  storage_account_ids   = [azurerm_storage_account.stblc.id]
}

resource "azurerm_log_analytics_data_export_rule" "export_logs" {
  name                    = var.monitoring_settings.data_export.name
  resource_group_name     = var.resource_group_name
  workspace_resource_id   = azurerm_log_analytics_workspace.law.id
  destination_resource_id = azurerm_storage_account.stblc.id
  table_names             = var.monitoring_settings.data_export.table_names
  enabled                 = var.monitoring_settings.data_export.enabled

  depends_on = [
    azurerm_role_assignment.law_storage_contributor
  ]
}

