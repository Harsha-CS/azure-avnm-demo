variable "name" {
  description = "The name of the security admin rule collection"
  type        = string
}

variable "network_group_id" {
  description = "A list of Network Group id strings"
  type        = list(string)
}

variable "security_configuration_id" {
  description = "The id of the security configuration"
  type        = string
}
