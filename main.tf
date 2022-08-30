
# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

locals {
  resource_group_name = upper("${var.application}-${var.environment}-rg")
  vnet_name = "${var.application}-${var.environment}-vnet"
  subnet_name = "${var.application}-${var.environment}-subnet"
  san_name = "${var.application}-${var.environment}"
  tags = {
    Code = "TechAssessment"
    Candidate = "Curtis Wilson"
  }
}

resource "azurerm_resource_group" "deployment" {
  name = local.resource_group_name
  location = var.location
  tags = merge(local.tags, var.default_tags, {
    type = "resource"
  })
}

module "vnet" {
  source = "./modules/vnet"
  depends_on = [
    azurerm_resource_group.deployment
  ]
  vnet_name = local.vnet_name
  location = var.location
  resource_group_name = local.resource_group_name
  address_space = var.address_space
  tags = merge(local.tags, var.default_tags, {
    type = "network"
  })
}

module "vmss" {
  source = "./modules/vmss"
  depends_on = [
    module.vnet
  ]
  virtual_network_name = local.vnet_name
  resource_group_name = local.resource_group_name
  subnet_address_space = var.subnet_address_space
  subnet_name = local.subnet_name
  san_name =  local.san_name
  location = azurerm_resource_group.deployment.location
  tags = merge(local.tags, var.default_tags)
}