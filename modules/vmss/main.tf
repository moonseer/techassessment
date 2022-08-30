resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 numeric  = false
}

#-----------------------------------
# Subnet
#-----------------------------------
resource "azurerm_subnet" "vmss_subnet" {
 name                   = var.subnet_name
 resource_group_name    = var.resource_group_name
 virtual_network_name   = var.virtual_network_name
 address_prefixes       = [var.subnet_address_space]
}

#-----------------------------------
# Log Analytics Workspace
#-----------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                  = "${var.san_name}-law"
  location              = var.location
  resource_group_name   = var.resource_group_name
  sku                   = var.log_analytics_workspace_sku
  retention_in_days     = 30
  tags = merge(var.tags, {
    type = "logs"
  })
}

#-----------------------------------
# Public IP for Load Balancer
#-----------------------------------
resource "azurerm_public_ip" "vmss_pip" {
 name                         = "${var.san_name}-pip"
 location                     = var.location
 resource_group_name          = var.resource_group_name
 allocation_method            = "Static"
 domain_name_label            = random_string.fqdn.result
 sku                          = "Standard"
 tags                         = merge(var.tags, {
                                  type = "frontend"
                                })
}

#-----------------------------------
# External Load Balancer with Public IP
#-----------------------------------
resource "azurerm_lb" "vmss_lb" {
 name                       = "${var.san_name}-lb"
 location                   = var.location
 resource_group_name        = var.resource_group_name
 sku                        = "Standard"

 frontend_ip_configuration {
   name                     = "PublicIPAddress"
   public_ip_address_id     = azurerm_public_ip.vmss_pip.id

 }

 tags                       = merge(var.tags, {
                            type = "frontend"
                          })
}

#---------------------------------------
# Backend address pool for Load Balancer
#---------------------------------------
resource "azurerm_lb_backend_address_pool" "bpepool" {
 loadbalancer_id            = azurerm_lb.vmss_lb.id
 name                       = "BackEndAddressPool"
}

#---------------------------------------
# Health Probe for resources
#---------------------------------------
resource "azurerm_lb_probe" "vmss_probe" {
 loadbalancer_id            = azurerm_lb.vmss_lb.id
 name                       = "http-probe"
 port                       = 80
}

#--------------------------
# Load Balancer Rules
#--------------------------
resource "azurerm_lb_rule" "lbnatrule" {
 loadbalancer_id                    = azurerm_lb.vmss_lb.id
 name                               = "http"
 protocol                           = "Tcp"
 frontend_port                      = 80
 backend_port                       = 80
 backend_address_pool_ids           = [azurerm_lb_backend_address_pool.bpepool.id]
 frontend_ip_configuration_name     = "PublicIPAddress"
 probe_id                           = azurerm_lb_probe.vmss_probe.id
}

#----------------------------------------------
# NSG - Create Rule to allow traffic on port 80
#----------------------------------------------
resource "azurerm_network_security_group" "vmss_nsg" {
  name                      = "${var.san_name}-nsg"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tags                        = merge(var.tags, {
                                  type = "Security"
                                })


  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#--------------------------
# NSG Association
#--------------------------
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                     = azurerm_subnet.vmss_subnet.id
  network_security_group_id     = azurerm_network_security_group.vmss_nsg.id
  depends_on = [
    azurerm_network_security_group.vmss_nsg
  ]
}

#---------------------------------------
# Linux Virutal machine scale set
#---------------------------------------
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  depends_on = [
    azurerm_network_security_group.vmss_nsg
  ]
  name                          = var.san_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Standard_F2"
  instances                     = 3
  admin_username                = "adminuser"
  admin_password                = "P@ssw0rd!!!"
  disable_password_authentication       = "false"
  custom_data                   = base64encode(file("./scripts/web.conf"))
  zones                         = var.availability_zones
  zone_balance                  = "true" 
  scale_in_policy = "Default"
  health_probe_id  = azurerm_lb_probe.vmss_probe.id
  platform_fault_domain_count = 5
  tags                         = merge(var.tags, {
                                  type = "vmss"
                                })
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${var.san_name}-vmss-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.vmss_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
    }
  }

  dynamic "automatic_instance_repair" {
    for_each = var.enable_automatic_instance_repair ? [1] : []
    content {
      enabled      = var.enable_automatic_instance_repair
      grace_period = "PT30M"
    }
  }
}

#-----------------------------------------------
# Auto Scaling for Virtual machine scale set
#-----------------------------------------------
resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  name                = "AutoscaleSetting"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 3
      minimum = 3
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = ["operations@company.com"]
    }
  }
}

#--------------------------------------------------------------
# Azure Log Analytics Workspace Agent Installation for Linux
#--------------------------------------------------------------
resource "azurerm_virtual_machine_scale_set_extension" "omsagentlinux" {
  depends_on = [
    azurerm_log_analytics_workspace.law
  ]
  name                         = "OmsAgentForLinux"
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "OmsAgentForLinux"
  type_handler_version         = "1.13"
  auto_upgrade_minor_version   = true
  virtual_machine_scale_set_id =  azurerm_linux_virtual_machine_scale_set.vmss.id

  settings = <<SETTINGS
    {
      "workspaceId": "${azurerm_log_analytics_workspace.law.id}"
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
    "workspaceKey": "${azurerm_log_analytics_workspace.law.primary_shared_key}"
    }
  PROTECTED_SETTINGS
}

#--------------------------------------
# azurerm monitoring diagnostics 
#--------------------------------------
resource "azurerm_monitor_diagnostic_setting" "vmmsdiag" {
  name                       = lower("${var.san_name}-diag")
  target_resource_id         = azurerm_linux_virtual_machine_scale_set.vmss.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  name                       = lower("nsg-${var.san_name}-diag")
  target_resource_id         = azurerm_network_security_group.vmss_nsg.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  dynamic "log" {
    for_each = var.nsg_diag_logs
    content {
      category = log.value
      enabled  = true

      retention_policy {
        enabled = false
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "lb-pip" {
  name                       = "${var.san_name}-pip-diag"
  target_resource_id         = azurerm_public_ip.vmss_pip.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  dynamic "log" {
    for_each = var.pip_diag_logs
    content {
      category = log.value
      enabled  = true

      retention_policy {
        enabled = false
      }
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "lb" {
  name                       = "${var.san_name}-lb-diag"
  target_resource_id         = azurerm_lb.vmss_lb.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  dynamic "log" {
    for_each = var.lb_diag_logs
    content {
      category = log.value
      enabled  = true

      retention_policy {
        enabled = false
      }
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}