variable "security_rule_collection_id" {
  description = "The id of the security rule collection"
  type        = string
}

variable "security_rules" {
  description = "The security rules to apply to the resource"
  type = list(object({
    name                    = string
    description             = string
    action                  = string
    direction               = string
    priority                = number
    protocol                = string
    source_port_ranges      = list(string)
    destination_port_ranges = list(string)
    source = list(object({
      address_prefix_type = string
      address_prefix      = string
    }))
    destination = list(object({
      address_prefix_type = string
      address_prefix      = string
    }))
  }))
}
