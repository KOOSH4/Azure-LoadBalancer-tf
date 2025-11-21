output "lb_id" {
  description = "ID of the load balancer."
  value       = azurerm_lb.lb.id
}

output "frontend_name" {
  description = "Name of the load balancer frontend configuration."
  value       = var.load_balancer_settings.load_balancer.frontend_name
}

output "pool_webs_id" {
  description = "Backend pool for web traffic."
  value       = azurerm_lb_backend_address_pool.pool_webs.id
}

output "pool_mgmt_id" {
  description = "Backend pool for management traffic."
  value       = azurerm_lb_backend_address_pool.pool_mgmt.id
}

output "probe_hp_lb_id" {
  description = "HTTPS probe ID."
  value       = azurerm_lb_probe.hp_lb.id
}

output "probe_hp_3389_id" {
  description = "RDP probe ID."
  value       = azurerm_lb_probe.hp_3389.id
}
