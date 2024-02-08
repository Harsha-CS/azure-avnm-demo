variable "location" {
  description = "The name of the location to deploy the resources to"
  type = string
}

variable "name" {
  description = "The name to include in the log analytics workspace name"
  type = string
}

variable "resource_group_name" {
  description = "The name of the resource group to deploy the resources to"
  type = string
}

variable "tags" {
  description = "The tags to apply to the resource"
  type = map(string)
}