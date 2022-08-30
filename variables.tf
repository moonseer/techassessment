variable "application" {
 type        = string
 description = ""
 default     = ""
}

variable "environment" {
 type        = string
 description = ""
 default     = ""
}

variable "location" {
 type        = string
 description = ""
 default     = ""
}

variable "default_tags" {
 description = ""
 type        = map(any)
 default     = {}
}

variable "address_space" {
 type        = string
 description = "VNET Address Space in CIDR Format"
 default     = ""
}

variable "subnet_address_space" {
 type        = string
 description = "Subnet Address Space in CIDR Format"
 default     = ""
}

variable "log_analytics_workspace_sku" {
  type = string
  description = "Log Analytics Workspace Sku Options (Free, PerNode, Premium, Standard, Standalone, Unlimited, CapacityReservation, and PerGB2018)"
  default = "PerGB2018"
}