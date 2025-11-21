output "vmss_id" {
  description = "ID of the web VMSS."
  value       = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
}
