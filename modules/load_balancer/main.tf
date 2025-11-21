resource "azurerm_public_ip" "pip_lb" {
  name                    = var.load_balancer_settings.public_ip.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = var.load_balancer_settings.public_ip.allocation_method
  sku                     = var.load_balancer_settings.public_ip.sku
  zones                   = var.load_balancer_settings.public_ip.zones
  ip_version              = var.load_balancer_settings.public_ip.ip_version
  idle_timeout_in_minutes = var.load_balancer_settings.public_ip.idle_timeout_in_minutes

  tags = var.tags
}

resource "azurerm_lb" "lb" {
  name                = var.load_balancer_settings.load_balancer.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.load_balancer_settings.load_balancer.sku

  frontend_ip_configuration {
    name                 = var.load_balancer_settings.load_balancer.frontend_name
    public_ip_address_id = azurerm_public_ip.pip_lb.id
  }

  tags = var.tags

  depends_on = [azurerm_public_ip.pip_lb]
}

resource "azurerm_lb_backend_address_pool" "pool_webs" {
  name            = var.load_balancer_settings.backend_pools.web_name
  loadbalancer_id = azurerm_lb.lb.id

  depends_on = [azurerm_lb.lb]
}

resource "azurerm_lb_probe" "hp_lb" {
  name                = var.load_balancer_settings.probes.https.name
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = var.load_balancer_settings.probes.https.protocol
  port                = var.load_balancer_settings.probes.https.port
  interval_in_seconds = var.load_balancer_settings.probes.https.interval_in_seconds
  number_of_probes    = var.load_balancer_settings.probes.https.number_of_probes

  depends_on = [azurerm_lb.lb]
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = var.load_balancer_settings.rules.https.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = var.load_balancer_settings.rules.https.protocol
  frontend_port                  = var.load_balancer_settings.rules.https.frontend_port
  backend_port                   = var.load_balancer_settings.rules.https.backend_port
  frontend_ip_configuration_name = var.load_balancer_settings.load_balancer.frontend_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool_webs.id]
  probe_id                       = azurerm_lb_probe.hp_lb.id
  floating_ip_enabled            = var.load_balancer_settings.rules.https.floating_ip_enabled
  disable_outbound_snat          = var.load_balancer_settings.rules.https.disable_outbound_snat

  depends_on = [
    azurerm_lb_backend_address_pool.pool_webs,
    azurerm_lb_probe.hp_lb
  ]
}

resource "azurerm_lb_outbound_rule" "out_lb" {
  name                     = var.load_balancer_settings.rules.outbound.name
  loadbalancer_id          = azurerm_lb.lb.id
  protocol                 = var.load_balancer_settings.rules.outbound.protocol
  backend_address_pool_id  = azurerm_lb_backend_address_pool.pool_webs.id
  allocated_outbound_ports = var.load_balancer_settings.rules.outbound.allocated_outbound_ports
  idle_timeout_in_minutes  = var.load_balancer_settings.rules.outbound.idle_timeout_in_minutes

  frontend_ip_configuration {
    name = var.load_balancer_settings.load_balancer.frontend_name
  }

  depends_on = [
    azurerm_lb_backend_address_pool.pool_webs,
    azurerm_lb_rule.lb_rule
  ]
}

resource "azurerm_lb_backend_address_pool" "pool_mgmt" {
  name            = var.load_balancer_settings.backend_pools.mgmt_name
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "hp_3389" {
  name                = var.load_balancer_settings.probes.rdp.name
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = var.load_balancer_settings.probes.rdp.protocol
  port                = var.load_balancer_settings.probes.rdp.port
  interval_in_seconds = var.load_balancer_settings.probes.rdp.interval_in_seconds
  number_of_probes    = var.load_balancer_settings.probes.rdp.number_of_probes
}

resource "azurerm_lb_rule" "rule_3389" {
  name                           = var.load_balancer_settings.rules.rdp.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = var.load_balancer_settings.rules.rdp.protocol
  frontend_port                  = var.load_balancer_settings.rules.rdp.frontend_port
  backend_port                   = var.load_balancer_settings.rules.rdp.backend_port
  frontend_ip_configuration_name = var.load_balancer_settings.load_balancer.frontend_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool_mgmt.id]
  probe_id                       = azurerm_lb_probe.hp_3389.id
  disable_outbound_snat          = var.load_balancer_settings.rules.rdp.disable_outbound_snat
}
