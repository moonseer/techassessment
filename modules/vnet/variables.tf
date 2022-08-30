variable "resource_group_name" {
  type = string
  description = "Name of Resource Group"
  default = ""
}

variable "location" {
  type = string
  description = "Resource Location"
  default = ""
}

variable "tags" {
  type = map(any)
  description = "Resource Tags"
}

variable "vnet_name" {
  type = string
  description = "VNET Name"
}

variable "address_space" {
  type = string
  description = "VNET address space in CIDR format"
}

variable "dns_servers" {
  type = list(any)
  description = "VNET dns servers"
  default = [  ]
}