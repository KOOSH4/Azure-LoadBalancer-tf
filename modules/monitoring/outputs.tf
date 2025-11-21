output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.law.id
}

output "storage_account_id" {
  description = "ID of the log storage account."
  value       = azurerm_storage_account.stblc.id
}

output "dcr_id" {
  description = "ID of the data collection rule."
  value       = azurerm_monitor_data_collection_rule.dcr_vmss.id
}
