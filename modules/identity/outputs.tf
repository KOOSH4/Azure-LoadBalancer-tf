output "backup_identity_id" {
  description = "ID of the backup user-assigned identity."
  value       = azurerm_user_assigned_identity.backup.id
}

output "backup_principal_id" {
  description = "Principal ID of the backup identity."
  value       = azurerm_user_assigned_identity.backup.principal_id
}

output "dcr_identity_id" {
  description = "ID of the DCR user-assigned identity."
  value       = azurerm_user_assigned_identity.dcr.id
}

output "dcr_principal_id" {
  description = "Principal ID of the DCR identity."
  value       = azurerm_user_assigned_identity.dcr.principal_id
}

output "log_identity_id" {
  description = "ID of the logging user-assigned identity."
  value       = azurerm_user_assigned_identity.log.id
}

output "log_identity_principal_id" {
  description = "Principal ID of the logging identity."
  value       = azurerm_user_assigned_identity.log.principal_id
}
