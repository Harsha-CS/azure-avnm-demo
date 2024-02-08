variable "members" {
  description = "The virtual networks to add to the network group"
  type        = list(string)
}

variable "network_group_id" {
  description = "The resource if of the network group"
  type        = string
}
