output "dns_zone_id" {
  description = "ID of the private DNS zone."
  value       = azurerm_private_dns_zone.dns_zone.id
}
