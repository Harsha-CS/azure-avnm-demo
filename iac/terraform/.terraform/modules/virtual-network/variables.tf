variable "address_space_vnet" {
  description = "The address space to assign to the virtual network"
  type        = list(string)
}

variable "dns_servers" {
  description = "The address space to assign to the Private Endpoint subnet"
  type        = list(string)
  default    = ["168.63.129.16"]
}

variable "law_resource_id" {
  description = "The resource id of the Log Analytics Workspace to send diagnostic logs to"
  type        = string
}

variable "location" {
  description = "The name of the location to provision the resources to"
  type        = string
}

variable "name" {
  description = "The name of the virtual network"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to deploy the resources to"
  type        = string
}

variable "subnets" {
  description = "The subnets to create in the virtual network"
  type        = list(object({
    name                 = string
    address_prefixes     = list(string)
    network_security_group_id = string
  }))
}

variable "tags" {
  description = "The tags to apply to the resource"
  type        = map(string)
}
