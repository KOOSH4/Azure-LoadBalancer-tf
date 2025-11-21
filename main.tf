# ===========================================================================
# MAIN CONFIGURATION
# ===========================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.51.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = false
    }
  }

  use_oidc        = true
  subscription_id = var.subscription_id
  client_id       = var.client_id
  tenant_id       = var.tenant_id
}

locals {
  common_tags = merge(var.base_tags, { Location = var.location })
}

data "azurerm_client_config" "current" {}

# Identity used across the stack
module "identity" {
  source              = "./modules/identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
  identity_names      = var.identity_names
}

# Logging, storage, and DCR
module "monitoring" {
  source                        = "./modules/monitoring"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tags                          = local.common_tags
  monitoring_settings           = var.monitoring_settings
  log_identity_id               = module.identity.log_identity_id
  log_identity_principal_id     = module.identity.log_identity_principal_id
  metrics_publisher_principal_id = module.identity.dcr_principal_id
}

# Key Vault and admin secrets
module "key_vault" {
  source                     = "./modules/key_vault"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  key_vault_settings         = var.key_vault_settings
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  current_object_id          = data.azurerm_client_config.current.object_id
  admin_username             = var.admin_username
  tags                       = local.common_tags
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

# Network, NSGs, and diagnostics
module "networking" {
  source                     = "./modules/networking"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tags                       = local.common_tags
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  allowed_rdp_cidr           = var.allowed_rdp_ip
  network_settings           = var.network_settings
}

# Public IP and load balancer
module "load_balancer" {
  source              = "./modules/load_balancer"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
  load_balancer_settings = var.load_balancer_settings
}

# Recovery Services Vault and policy
module "backup" {
  source              = "./modules/backup"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
  backup_settings     = var.backup_settings
}

# Private endpoints for storage and backup vault
module "private_endpoints" {
  source                    = "./modules/private_endpoints"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  subnet_id                 = module.networking.apps_subnet_id
  storage_account_id        = module.monitoring.storage_account_id
  recovery_services_vault_id = module.backup.rsv_id
  private_endpoint_settings = var.private_endpoint_settings
}

# Private DNS zone and mappings
module "private_dns" {
  source              = "./modules/private_dns"
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
  vnet_id             = module.networking.vnet_id
  dns_settings        = var.dns_settings
}

# Management VM and NIC wiring
module "management_vm" {
  source              = "./modules/management_vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
  subnet_id           = module.networking.mgmt_subnet_id
  asg_id              = module.networking.asg_mgmt_id
  backend_pool_id     = module.load_balancer.pool_mgmt_id
  admin_username      = module.key_vault.admin_username_secret_value
  admin_password      = module.key_vault.admin_password_secret_value
  mgmt_vm_settings    = var.mgmt_vm_settings
}

# Web VMSS, diagnostics, and autoscale
module "web_vmss" {
  source                       = "./modules/web_vmss"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  tags                         = local.common_tags
  subnet_id                    = module.networking.apps_subnet_id
  backend_pool_id              = module.load_balancer.pool_webs_id
  asg_id                       = module.networking.asg_web_id
  health_probe_id              = module.load_balancer.probe_hp_lb_id
  identity_ids                 = [module.identity.backup_identity_id, module.identity.dcr_identity_id]
  dcr_id                       = module.monitoring.dcr_id
  admin_username               = module.key_vault.admin_username_secret_value
  admin_password               = module.key_vault.admin_password_secret_value
  vmss_sku                     = var.vmss_sku
  vmss_zone1_min_instances     = var.vmss_zone1_min_instances
  vmss_zone1_max_instances     = var.vmss_zone1_max_instances
  business_hours_min_instances = var.business_hours_min_instances
  business_hours_start         = var.business_hours_start
  business_hours_end           = var.business_hours_end
  autoscale_cpu_threshold_out  = var.autoscale_cpu_threshold_out
  autoscale_cpu_threshold_in   = var.autoscale_cpu_threshold_in
  autoscale_notification_emails = var.autoscale_notification_emails
  vmss_settings                = var.vmss_settings
}
