variable "vm_username" {
  description = "The username for the virtual machine"
  type = string
}

variable "vm_password" {
  description = "The password for the virtual machine"
  type = string
  sensitive = true
}

variable "management_group_id" {
  description = "The management group id the central virtual network manager is scoped to"
  type = string
}

variable "network_watcher_name_r1" {
  description = "The name of the network watcher in the primary region"
  type = string
  default = "NetworkWatcher_eastus"
}

variable "network_watcher_name_r2" {
  description = "The name of the network watcher in the secondary region"
  type = string
  default = "NetworkWatcher_westcentralus"
}

variable "network_watcher_resource_group_name" {
  description = "The name of the network watcher resource group"
  type = string
  default = "NetworkWatcherRG"
}

variable "primary_location" {
  description = "The primary location for resources to be deployed"
  type = string
  default = "eastus"
}

variable "secondary_location" {
  description = "The secondary location for resources to be deployed"
  type = string
  default = "westcentralus"
}

variable "tags" {
  description = "The tags to apply to the resource"
  type = map(string)
  default = {
    environment = "demo"
    product = "avnm"
  }
}

variable "trusted_ip" {
  description = "The secondary location for resources to be deployed"
  type = string
}