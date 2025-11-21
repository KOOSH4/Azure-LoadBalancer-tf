resource "azurerm_network_interface" "nic_mgmt" {
  name                = var.mgmt_vm_settings.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = var.mgmt_vm_settings.ip_configuration_name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.mgmt_vm_settings.private_ip_allocation
    private_ip_address_version    = var.mgmt_vm_settings.private_ip_version
    primary                       = true
  }

  tags = var.tags
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_mgmt_lb" {
  network_interface_id    = azurerm_network_interface.nic_mgmt.id
  ip_configuration_name   = var.mgmt_vm_settings.ip_configuration_name
  backend_address_pool_id = var.backend_pool_id
}

resource "azurerm_network_interface_application_security_group_association" "nic_mgmt_asg" {
  network_interface_id          = azurerm_network_interface.nic_mgmt.id
  application_security_group_id = var.asg_id
}

resource "azurerm_windows_virtual_machine" "vm_mgmt" {
  name                  = var.mgmt_vm_settings.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.mgmt_vm_settings.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_mgmt.id]

  source_image_reference {
    publisher = var.mgmt_vm_settings.source_image.publisher
    offer     = var.mgmt_vm_settings.source_image.offer
    sku       = var.mgmt_vm_settings.source_image.sku
    version   = var.mgmt_vm_settings.source_image.version
  }

  os_disk {
    caching              = var.mgmt_vm_settings.os_disk.caching
    storage_account_type = var.mgmt_vm_settings.os_disk.storage_account_type
    name                 = var.mgmt_vm_settings.os_disk.name
  }

  secure_boot_enabled = var.mgmt_vm_settings.secure_boot_enabled
  vtpm_enabled        = var.mgmt_vm_settings.vtpm_enabled

  tags = merge(var.tags, {
    Role = "Management"
  })
}
