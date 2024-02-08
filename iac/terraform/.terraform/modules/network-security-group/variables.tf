variable "flowLogStorageAccountId" {
  description = "The ID of the storage account to send flow logs to"
  type        = string
}

variable "law_resource_id" {
  description = "The resource id of the Log Analytics Workspace to sent diagnostic logs to"
  type        = string
}

variable "location" {
  description = "The name of the location to deploy the resources to"
  type        = string
}

variable "name" {
  description = "The name to apply the network security group"
  type        = string
}

variable "network_watcher_name" {
  description = "The name of the Network Watcher"
  type        = string
}

variable "network_watcher_resource_group_name" {
  description = "The resource group name the Network Watcher is deployed in"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to deploy the resources to"
  type        = string
}

variable "security_rules" {
  description = "The security rules to apply to the resource"
  type = list(object({
    name                         = string
    description                  = string
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    source_port_range            = string
    source_port_ranges           = optional(list(string))
    destination_port_range       = optional(string)
    destination_port_ranges      = optional(list(string))
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(list(string))
  }))
}

variable "tags" {
  description = "The tags to apply to the resource"
  type        = map(string)
}

variable "trafficAnalyticsWorkspaceGuid" {
  description = "The workspace resource guid to send traffic analytics to"
  type        = string
}

variable "trafficAnalyticsWorkspaceRegion" {
  description = "The workspace region to send traffic analytics to"
  type        = string
}

variable "trafficAnalyticsWorkspaceId" {
  description = "The workspace resource id send traffic analytics to"
  type        = string
}


