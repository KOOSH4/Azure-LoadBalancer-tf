output "key_vault_id" {
  description = "ID of the Key Vault."
  value       = azurerm_key_vault.vm_credentials.id
}

output "admin_username_secret_value" {
  description = "Admin username stored in Key Vault."
  value       = azurerm_key_vault_secret.vm_admin_username.value
  sensitive   = true
}

output "admin_password_secret_value" {
  description = "Admin password stored in Key Vault."
  value       = azurerm_key_vault_secret.vm_admin_password.value
  sensitive   = true
}
