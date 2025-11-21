output "apps_subnet_id" {
  description = "ID of the applications subnet."
  value       = azurerm_subnet.sub_apps.id
}

output "mgmt_subnet_id" {
  description = "ID of the management subnet."
  value       = azurerm_subnet.sub_mgmt.id
}

output "asg_web_id" {
  description = "ID of the web ASG."
  value       = azurerm_application_security_group.asg_web_tier.id
}

output "asg_mgmt_id" {
  description = "ID of the management ASG."
  value       = azurerm_application_security_group.asg_mgmt_tier.id
}

output "vnet_id" {
  description = "ID of the shared VNet."
  value       = azurerm_virtual_network.vnet_shared.id
}

output "nsg_apps_id" {
  description = "ID of the apps NSG."
  value       = azurerm_network_security_group.nsg_sub_apps.id
}

output "nsg_mgmt_id" {
  description = "ID of the management NSG."
  value       = azurerm_network_security_group.nsg_sub_mgmt.id
}
