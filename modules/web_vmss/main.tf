resource "azurerm_windows_virtual_machine_scale_set" "vmss_web_zone1" {
  name                = var.vmss_settings.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.vmss_sku
  instances           = var.vmss_zone1_min_instances
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  zones        = var.vmss_settings.zones
  zone_balance = var.vmss_settings.zone_balance

  upgrade_mode    = var.vmss_settings.upgrade_mode
  health_probe_id = var.health_probe_id

  source_image_reference {
    publisher = var.vmss_settings.source_image.publisher
    offer     = var.vmss_settings.source_image.offer
    sku       = var.vmss_settings.source_image.sku
    version   = var.vmss_settings.source_image.version
  }

  os_disk {
    caching              = var.vmss_settings.os_disk.caching
    storage_account_type = var.vmss_settings.os_disk.storage_account_type
  }

  identity {
    type = "UserAssigned"
    identity_ids = var.identity_ids
  }

  network_interface {
    name    = var.vmss_settings.network_interface_name
    primary = true

    ip_configuration {
      name                                   = var.vmss_settings.ip_configuration_name
      primary                                = true
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = [var.backend_pool_id]
      application_security_group_ids         = [var.asg_id]
    }
  }

  extension {
    name                       = var.vmss_settings.extension.name
    publisher                  = var.vmss_settings.extension.publisher
    type                       = var.vmss_settings.extension.type
    type_handler_version       = var.vmss_settings.extension.type_handler_version
    auto_upgrade_minor_version = var.vmss_settings.extension.auto_upgrade_minor_version
  }

  automatic_instance_repair {
    enabled      = var.vmss_settings.automatic_instance_repair.enabled
    grace_period = var.vmss_settings.automatic_instance_repair.grace_period
  }

  tags = merge(var.tags, var.vmss_settings.extra_tags)
}

resource "azurerm_monitor_data_collection_rule_association" "dcra_zone1" {
  name                    = var.vmss_settings.dcra_name
  target_resource_id      = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
  data_collection_rule_id = var.dcr_id
}

resource "azurerm_monitor_autoscale_setting" "vmss_zone1_autoscale" {
  name                = var.vmss_settings.autoscale.name
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id

  profile {
    name = var.vmss_settings.autoscale.default_profile_name

    capacity {
      default = var.vmss_zone1_min_instances
      minimum = var.vmss_zone1_min_instances
      maximum = var.vmss_zone1_max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.autoscale_cpu_threshold_out
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.autoscale_cpu_threshold_in
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss_web_zone1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.vmss_settings.autoscale.memory_threshold_bytes
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  profile {
    name = var.vmss_settings.autoscale.business_hours_profile_name

    capacity {
      default = var.business_hours_min_instances
      minimum = var.business_hours_min_instances
      maximum = var.vmss_zone1_max_instances
    }

    recurrence {
      timezone = var.vmss_settings.autoscale.timezone
      days     = var.vmss_settings.autoscale.business_days
      hours    = [var.business_hours_start]
      minutes  = [0]
    }
  }

  profile {
    name = var.vmss_settings.autoscale.after_hours_profile_name

    capacity {
      default = var.vmss_zone1_min_instances
      minimum = var.vmss_zone1_min_instances
      maximum = var.vmss_settings.autoscale.after_hours_max_instances
    }

    recurrence {
      timezone = var.vmss_settings.autoscale.timezone
      days     = var.vmss_settings.autoscale.business_days
      hours    = [var.business_hours_end]
      minutes  = [0]
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      custom_emails                         = var.autoscale_notification_emails
    }
  }

  tags = var.tags
}
