output "vm_id" {
  description = "ID of the management VM."
  value       = azurerm_windows_virtual_machine.vm_mgmt.id
}

output "nic_id" {
  description = "ID of the management VM NIC."
  value       = azurerm_network_interface.nic_mgmt.id
}
