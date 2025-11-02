terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.51.0"
    }
  }
}

provider "azurerm" {
  features {
  }
  use_oidc = true
  subscription_id   = var.subscription_id
  client_id         = var.client_id
  tenant_id         = var.tenant_id
}

resource "random_string" "rg_suffix" {
  length  = 6
  upper   = false
  special = false
}


resource "azurerm_network_security_group" "nsg_sub_apps" {
  name                = "nsg-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "RDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.100.0.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 250
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_sub_mgmt" {
  name                = "nsg-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "RDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "109.41.113.107"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vnet_shared" {
  name                = "vnet-wss-lab-sec-001"
 location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.100.0.0/16"]
  tags = {
    owner = "Koosha"
  }
}

resource "azurerm_subnet" "sub_apps" {
  name                                          = "snet-app-wss-lab-sec-001"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.vnet_shared.name
  address_prefixes                              = ["10.100.1.0/24"]
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet_network_security_group_association" "sub_apps_nsg" {
  subnet_id                 = azurerm_subnet.sub_apps.id
  network_security_group_id = azurerm_network_security_group.nsg_sub_apps.id
}

resource "azurerm_subnet" "sub_mgmt" {
  name                                          = "snet-mngmnt-wss-lab-sec-002"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.vnet_shared.name
  address_prefixes                              = ["10.100.0.0/24"]
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet_network_security_group_association" "sub_mgmt_nsg" {
  subnet_id                 = azurerm_subnet.sub_mgmt.id
  network_security_group_id = azurerm_network_security_group.nsg_sub_mgmt.id
}

resource "azurerm_public_ip" "pip_lb" {
  name                    = "Pip-LB"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  zones                   = ["1", "2", "3"]
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4
}

resource "azurerm_public_ip" "pip_vm_mgmt" {
  name                    = "vm-mgmt-demo-sw-ip"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  zones                   = ["1"]
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4
}

resource "azurerm_lb" "lb" {
  name                = "lbi-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PIP-LB"
    public_ip_address_id = azurerm_public_ip.pip_lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "pool_webs" {
  name            = "Pool-webs"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "hp_lb" {
  name                = "HP-LB"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 1
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "LB-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "PIP-LB"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool_webs.id]
  probe_id                       = azurerm_lb_probe.hp_lb.id
  floating_ip_enabled             = false
  disable_outbound_snat          = true
}

resource "azurerm_lb_outbound_rule" "out_lb" {
  name                    = "out-LB"
  loadbalancer_id         = azurerm_lb.lb.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool_webs.id
  allocated_outbound_ports = 31992
  idle_timeout_in_minutes  = 4

  frontend_ip_configuration {
    name = "PIP-LB"
  }
}

resource "azurerm_network_interface" "nic_mgmt" {
  name                = "vm-mgmt-demo-sw376_z1"
  location                = var.location
  resource_group_name     = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub_mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_vm_mgmt.id
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

  accelerated_networking_enabled = true
}

resource "azurerm_network_interface" "nic_web1" {
  name                = "vm-web1-demo-sw218_z1"
  location                = var.location
  resource_group_name     = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub_apps.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

  accelerated_networking_enabled = true
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_web1_lb" {
  network_interface_id    = azurerm_network_interface.nic_web1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool_webs.id
}

resource "azurerm_network_interface" "nic_web2" {
  name                = "vm-web2-demo-sw10_z2"
  location                = var.location
  resource_group_name     = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub_apps.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

  accelerated_networking_enabled = true
}
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                = "kv-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]
  }
}

resource "random_password" "vm_password" {
  length           = 20
  special          = true
  override_special = "!@#$%&*()-_=+[]{}:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_key_vault_secret" "vm_password" {
  name         = "vm-admin-password"
  value        = random_password.vm_password.result
  key_vault_id = azurerm_key_vault.kv.id
}
resource "azurerm_network_interface_backend_address_pool_association" "nic_web2_lb" {
  network_interface_id    = azurerm_network_interface.nic_web2.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool_webs.id
}

resource "azurerm_windows_virtual_machine" "vm_mgmt" {
  name                  = "vm-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  size                  = "Standard_D2as_v5"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_mgmt.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-mgmt-demo-sw_OsDisk"
  }

  secure_boot_enabled = true
  vtpm_enabled        = true
}

resource "azurerm_windows_virtual_machine" "vm_web1" {
  name                  = "vm-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  size                  = "Standard_D2as_v5"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_web1.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-web1-demo-sw_OsDisk"
  }

  secure_boot_enabled = true
  vtpm_enabled        = true
}

resource "azurerm_windows_virtual_machine" "vm_web2" {
  name                  = "vm-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  size                  = "Standard_D2as_v5"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_web2.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-web2-demo-sw_OsDisk"
  }

  secure_boot_enabled = true
  vtpm_enabled        = true
}

resource "azurerm_recovery_services_vault" "rsv" {
  name                = "rsv-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku                 = "Standard"
  soft_delete_enabled = true
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_storage_account" "stblc" {
  name                     = "stblcwsslabsec001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bas-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.sub_mgmt.id
    public_ip_address_id = azurerm_public_ip.pip_vm_mgmt.id
  }
}

resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "test.local"
  resource_group_name     = var.resource_group_name
}

resource "azurerm_private_dns_a_record" "dns_vm_mgmt" {
  name                = "vm-mgmt-demo-sw"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name     = var.resource_group_name
  ttl                 = 10
  records             = ["10.100.0.4"]
}

resource "azurerm_private_dns_a_record" "dns_vm_web1" {
  name                = "vm-web1-demo-sw"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name     = var.resource_group_name
  ttl                 = 10
  records             = ["10.100.1.4"]
}

resource "azurerm_private_dns_a_record" "dns_vm_web2" {
  name                = "vm-web2-demo-sw"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name     = var.resource_group_name
  ttl                 = 10
  records             = ["10.100.1.5"]
}

resource "azurerm_private_dns_a_record" "dns_web1" {
  name                = "web1"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name     = var.resource_group_name
  ttl                 = 3600
  records             = ["10.100.1.4"]
}

resource "azurerm_private_dns_a_record" "dns_web2" {
  name                = "web2"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name     = var.resource_group_name
  ttl                 = 3600
  records             = ["10.100.1.5"]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = "localdns"
  resource_group_name     = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet_shared.id
  registration_enabled  = true
}
#=============================================================================
# NETWORK SECURITY GROUPS
#=============================================================================

resource "azurerm_network_security_group" "nsg_sub_apps" {
  name                = "nsg-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "RDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.100.0.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 250
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_network_security_group" "nsg_sub_mgmt" {
  name                = "nsg-mgmt-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowRDPFromSpecificIP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "109.41.113.107/32"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.rg]
}

#=============================================================================
# VIRTUAL NETWORK AND SUBNETS
#=============================================================================

resource "azurerm_virtual_network" "vnet_shared" {
  name                = "vnet-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.100.0.0/16"]
  
  tags = {
    owner = "amir"
  }

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_subnet" "sub_apps" {
  name                 = "snet-app-wss-lab-sec-001"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_shared.name
  address_prefixes     = ["10.100.1.0/24"]
  
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true

  depends_on = [azurerm_virtual_network.vnet_shared]
}

resource "azurerm_subnet" "sub_mgmt" {
  name                 = "snet-mngmnt-wss-lab-sec-002"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_shared.name
  address_prefixes     = ["10.100.0.0/24"]
  
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true

  depends_on = [azurerm_virtual_network.vnet_shared]
}

# Azure Bastion requires a subnet named exactly "AzureBastionSubnet"
resource "azurerm_subnet" "sub_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_shared.name
  address_prefixes     = ["10.100.2.0/26"]  # Minimum /26 required for Bastion

  depends_on = [azurerm_virtual_network.vnet_shared]
}

#=============================================================================
# SUBNET NSG ASSOCIATIONS
#=============================================================================

resource "azurerm_subnet_network_security_group_association" "sub_apps_nsg" {
  subnet_id                 = azurerm_subnet.sub_apps.id
  network_security_group_id = azurerm_network_security_group.nsg_sub_apps.id

  depends_on = [
    azurerm_subnet.sub_apps,
    azurerm_network_security_group.nsg_sub_apps
  ]
}

resource "azurerm_subnet_network_security_group_association" "sub_mgmt_nsg" {
  subnet_id                 = azurerm_subnet.sub_mgmt.id
  network_security_group_id = azurerm_network_security_group.nsg_sub_mgmt.id

  depends_on = [
    azurerm_subnet.sub_mgmt,
    azurerm_network_security_group.nsg_sub_mgmt
  ]
}

#=============================================================================
# PUBLIC IP ADDRESSES
#=============================================================================

resource "azurerm_public_ip" "pip_lb" {
  name                    = "pip-lb-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  zones                   = ["1", "2", "3"]
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_public_ip" "pip_bastion" {
  name                    = "pip-bastion-wss-lab-sec-001"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4

  depends_on = [azurerm_resource_group.rg]
}

#=============================================================================
# LOAD BALANCER
#=============================================================================

resource "azurerm_lb" "lb" {
  name                = "lbi-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PIP-LB"
    public_ip_address_id = azurerm_public_ip.pip_lb.id
  }

  depends_on = [azurerm_public_ip.pip_lb]
}

resource "azurerm_lb_backend_address_pool" "pool_webs" {
  name            = "Pool-webs"
  loadbalancer_id = azurerm_lb.lb.id

  depends_on = [azurerm_lb.lb]
}

resource "azurerm_lb_probe" "hp_lb" {
  name                = "HP-LB"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 1

  depends_on = [azurerm_lb.lb]
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "LB-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "PIP-LB"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool_webs.id]
  probe_id                       = azurerm_lb_probe.hp_lb.id
  enable_floating_ip             = false
  disable_outbound_snat          = true

  depends_on = [
    azurerm_lb_backend_address_pool.pool_webs,
    azurerm_lb_probe.hp_lb
  ]
}

resource "azurerm_lb_outbound_rule" "out_lb" {
  name                     = "out-LB"
  loadbalancer_id          = azurerm_lb.lb.id
  protocol                 = "All"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.pool_webs.id
  allocated_outbound_ports = 31992
  idle_timeout_in_minutes  = 4

  frontend_ip_configuration {
    name = "PIP-LB"
  }

  depends_on = [
    azurerm_lb_backend_address_pool.pool_webs,
    azurerm_lb_rule.lb_rule
  ]
}

#=============================================================================
# NETWORK INTERFACES
#=============================================================================

resource "azurerm_network_interface" "nic_mgmt" {
  name                          = "nic-vm-mgmt-wss-lab-sec-001"
  location                      = var.location
  resource_group_name           = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub_mgmt.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

  depends_on = [azurerm_subnet.sub_mgmt]
}

resource "azurerm_network_interface" "nic_web1" {
  name                          = "nic-vm-web1-wss-lab-sec-001"
  location                      = var.location
  resource_group_name           = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub_apps.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

  depends_on = [azurerm_subnet.sub_apps]
}

resource "azurerm_network_interface" "nic_web2" {
  name                          = "nic-vm-web2-wss-lab-sec-001"
  location                      = var.location
  resource_group_name           = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub_apps.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

  depends_on = [azurerm_subnet.sub_apps]
}

#=============================================================================
# NIC BACKEND POOL ASSOCIATIONS
#=============================================================================

resource "azurerm_network_interface_backend_address_pool_association" "nic_web1_lb" {
  network_interface_id    = azurerm_network_interface.nic_web1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool_webs.id

  depends_on = [
    azurerm_network_interface.nic_web1,
    azurerm_lb_backend_address_pool.pool_webs
  ]
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_web2_lb" {
  network_interface_id    = azurerm_network_interface.nic_web2.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool_webs.id

  depends_on = [
    azurerm_network_interface.nic_web2,
    azurerm_lb_backend_address_pool.pool_webs
  ]
}

#=============================================================================
# VIRTUAL MACHINES
#=============================================================================

resource "azurerm_windows_virtual_machine" "vm_mgmt" {
  name                  = "vm-mgmt-wss-lab-sec-001"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_D2as_v5"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_mgmt.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-vm-mgmt-wss-lab-sec-001"
  }

  secure_boot_enabled = true
  vtpm_enabled        = true

  depends_on = [azurerm_network_interface.nic_mgmt]
}

resource "azurerm_windows_virtual_machine" "vm_web1" {
  name                  = "vm-web1-wss-lab-sec-001"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_D2as_v5"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_web1.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-vm-web1-wss-lab-sec-001"
  }

  secure_boot_enabled = true
  vtpm_enabled        = true

  depends_on = [azurerm_network_interface.nic_web1]
}

resource "azurerm_windows_virtual_machine" "vm_web2" {
  name                  = "vm-web2-wss-lab-sec-001"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_D2as_v5"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_web2.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-vm-web2-wss-lab-sec-001"
  }

  secure_boot_enabled = true
  vtpm_enabled        = true

  depends_on = [azurerm_network_interface.nic_web2]
}

#=============================================================================
# AZURE BASTION
#=============================================================================

resource "azurerm_bastion_host" "bastion" {
  name                = "bas-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  
  # Optional: Enable copy/paste, file transfer, and shareable link features
  copy_paste_enabled     = true
  file_copy_enabled      = true
  shareable_link_enabled = false
  tunneling_enabled      = true

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.sub_bastion.id
    public_ip_address_id = azurerm_public_ip.pip_bastion.id
  }

  depends_on = [
    azurerm_subnet.sub_bastion,
    azurerm_public_ip.pip_bastion
  ]
}

#=============================================================================
# RECOVERY SERVICES VAULT
#=============================================================================

resource "azurerm_recovery_services_vault" "rsv" {
  name                = "rsv-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  soft_delete_enabled = true

  depends_on = [azurerm_resource_group.rg]
}

#=============================================================================
# LOG ANALYTICS WORKSPACE
#=============================================================================

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  depends_on = [azurerm_resource_group.rg]
}

#=============================================================================
# STORAGE ACCOUNTS
#=============================================================================

resource "azurerm_storage_account" "stblc" {
  name                     = "stblcwsslabsec001"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  depends_on = [azurerm_resource_group.rg]
}

#=============================================================================
# PRIVATE DNS ZONE
#=============================================================================

resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "test.local"
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = "localdns"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet_shared.id
  registration_enabled  = true

  depends_on = [
    azurerm_private_dns_zone.dns_zone,
    azurerm_virtual_network.vnet_shared
  ]
}

#=============================================================================
# PRIVATE DNS A RECORDS
#=============================================================================

resource "azurerm_private_dns_a_record" "dns_vm_mgmt" {
  name                = "vm-mgmt-demo-sw"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = 10
  records             = ["10.100.0.4"]

  depends_on = [azurerm_private_dns_zone.dns_zone]
}

resource "azurerm_private_dns_a_record" "dns_vm_web1" {
  name                = "vm-web1-demo-sw"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = 10
  records             = ["10.100.1.4"]

  depends_on = [azurerm_private_dns_zone.dns_zone]
}

resource "azurerm_private_dns_a_record" "dns_vm_web2" {
  name                = "vm-web2-demo-sw"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = 10
  records             = ["10.100.1.5"]

  depends_on = [azurerm_private_dns_zone.dns_zone]
}

resource "azurerm_private_dns_a_record" "dns_web1" {
  name                = "web1"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  records             = ["10.100.1.4"]

  depends_on = [azurerm_private_dns_zone.dns_zone]
}

resource "azurerm_private_dns_a_record" "dns_web2" {
  name                = "web2"
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  records             = ["10.100.1.5"]

  depends_on = [azurerm_private_dns_zone.dns_zone]
}