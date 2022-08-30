variable "resource_group_name" {
  type = string
  description = "Name of Resource Group"
  default = ""
}

variable "virtual_network_name" {
  type = string
  description = "Name of virtual network"
  default = ""
}

variable "subnet_name" {
  type = string
  description = "Name of subnet"
  default = ""
}

variable "tags" {
 description = ""
 type        = map(any)
 default     = {}
}

variable "subnet_address_space" {
  type = string
  description = "Subnet address space in CIDR format"
}

variable "san_name" {
  type = string
  description = "San_name value"
}

variable "location" {
  type = string
  description = "Resource Location"
  default = ""
}

variable "log_analytics_workspace_sku" {
  type = string
  description = "Log Analytics Workspace Sku Options (Free, PerNode, Premium, Standard, Standalone, Unlimited, CapacityReservation, and PerGB2018)"
  default = "PerGB2018"
}

variable "enable_automatic_instance_repair" {
  description = "Should the automatic instance repair be enabled on this Virtual Machine Scale Set?"
  default     = true
}

variable "availability_zones" {
  description = "A list of Availability Zones in which the Virtual Machines in this Scale Set should be created in"
  default     = [1, 2, 3]
}

variable "nsg_diag_logs" {
  description = "NSG Monitoring Category details for Azure Diagnostic setting"
  default     = ["NetworkSecurityGroupEvent", "NetworkSecurityGroupRuleCounter"]
}

variable "pip_diag_logs" {
  description = "Load balancer Public IP Monitoring Category details for Azure Diagnostic setting"
  default     = ["DDoSProtectionNotifications", "DDoSMitigationFlowLogs", "DDoSMitigationReports"]
}

variable "lb_diag_logs" {
  description = "Load balancer Category details for Azure Diagnostic setting"
  default     = ["LoadBalancerAlertEvent"]
}