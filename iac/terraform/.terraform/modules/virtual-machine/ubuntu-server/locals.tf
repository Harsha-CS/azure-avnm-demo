locals {

  # Network variables
  ip_configuration_name = "primary"

  # Storage variables
  os_disk_name          = "mdos"
  os_disk_caching       = "ReadWrite"
  data_disk_name        = "mddata"
  data_disk_caching       = "ReadWrite"
  data_disk_lun         = 10

  # Extension variables
  monitor_agent_handler_version = "1.21"
  custom_script_extension_version = "2.1"
  automatic_extension_ugprade = true
}
