variable "principal_id" {
  description = "The ID of the role definition to assign"
  type = string
}

variable "role_details" {
  description = "The details of the role assignment"
  type = list(object({
    description = optional(string)
    role_definition_id = string
    condition = optional(string)
  }))
}

variable "scope" {
  description = "The scope at which the role assignment applies"
  type = string
}