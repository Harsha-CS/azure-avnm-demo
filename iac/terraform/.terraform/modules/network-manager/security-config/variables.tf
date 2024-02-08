variable "apply_on_network_intent_policy_based_services" {
  description = "Specify whether security rules should apply to subnets containing services that use network intent policies"
  type        = list(string)
  default     = ["None"]

  validation {
    condition     = !contains([for item in var.apply_on_network_intent_policy_based_services: contains( ["None", "All", "AllowRulesOnly"], item)], false)
    error_message = "The only supported values are 'None', 'All', and 'AllowRulesOnly'"
  }
}

variable "description" {
  description = "The description of the security configuration"
  type        = string
}

variable "name" {
  description = "The name of the security configuration"
  type        = string
}

variable "network_manager_id" {
  description = "The resource id of the network manager"
  type        = string
}
