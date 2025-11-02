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
  use_oidc        = true
  subscription_id = var.subscription_id
  client_id       = var.client_id
  tenant_id       = var.tenant_id
}




resource "azurerm_network_security_group" "security_group" {
  name                = "nsg-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
}


resource "azurerm_virtual_network" "Vnet" {
  name                = "vnet-wss-lab-sec-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  subnet {
    name             = "snet-app-wss-lab-sec-001"
    address_prefixes = ["10.0.1.0/24"]
  }

  subnet {
    name             = "snet-mngmnt-wss-lab-sec-002"
    address_prefixes = ["10.0.2.0/24"]
    security_group   = azurerm_network_security_group.security_group.id
  }

  tags = {
    environment = "Production"
  }
}