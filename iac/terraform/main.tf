# Create a random string
resource "random_string" "unique" {
  length      = 5
  min_numeric = 5
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

###################################################################
# Create the resource group
#
#
###################################################################

resource "azurerm_resource_group" "rg_mgmt" {
  name     = "rg-demo-avnm-mgmt${random_string.unique.result}"
  location = var.primary_location
  tags     = local.tags
}

resource "azurerm_resource_group" "rg_p" {
  name     = "rg-demo-avnm-p${random_string.unique.result}"
  location = var.primary_location
  tags     = local.tags
}

resource "azurerm_resource_group" "rg_np" {
  name     = "rg-demo-avnm-np${random_string.unique.result}"
  location = var.primary_location
  tags     = local.tags
}

resource "azurerm_resource_group" "rg_s" {
  name     = "rg-demo-avnm-s${random_string.unique.result}"
  location = var.primary_location
  tags     = local.tags
}

###################################################################
# Create the Log Analytics Workspace used to store the flow logs
#
###################################################################

module "law_central" {
  depends_on = [azurerm_resource_group.rg_mgmt]

  source              = "./.terraform/modules/monitor/log-analytics-workspace"
  name                = "lawcent${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tags                = local.tags
}

###################################################################
# Create the user-assigned managed identity used
# by the Azure Monitor Agent extension running on virtual machines
#
###################################################################

module "umi_ama" {
  depends_on = [
    azurerm_resource_group.rg_mgmt,
    module.law_central
  ]

  source              = "./.terraform/modules/managed-identity"
  name                = "umiama${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tags                = local.tags
}

###################################################################
# Create the Azure Storage Accounts used to store the 
# network security group and vnet flow lows
#
###################################################################

module "storage_account_flow_logs_r1" {
  depends_on = [
    azurerm_resource_group.rg_mgmt,
    module.law_central
  ]

  source              = "./.terraform/modules/storage-account"
  name                = "stlogsr1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tags                = local.tags

  law_resource_id = module.law_central.id
}

module "storage_account_flow_logs_r2" {
  depends_on = [
    azurerm_resource_group.rg_mgmt,
    module.law_central
  ]

  source              = "./.terraform/modules/storage-account"
  name                = "stlogsr2${random_string.unique.result}"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tags                = local.tags

  law_resource_id = module.law_central.id
}

###################################################################
# Create demo virtual network, network security group, and
# virtual machine
###################################################################

module "pip_vm1_mgmt" {
  depends_on = [ 
    azurerm_resource_group.rg_mgmt,
    module.law_central
  ]

  source              = "./.terraform/modules/public-ip"
  name                = "pipvm1mgmt${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name

  law_resource_id = module.law_central.id
  tags                = local.tags
}

module "pip_vm2_mgmt" {
  depends_on = [ 
    azurerm_resource_group.rg_mgmt,
    module.law_central
  ]

  source              = "./.terraform/modules/public-ip"
  name                = "pipvm2mgmt${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name

  law_resource_id = module.law_central.id
  tags                = local.tags
}

module "nsg_mgmt_pri" {
  depends_on = [
    module.law_central,
    module.storage_account_flow_logs_r1
  ]

  source              = "./.terraform/modules/network-security-group"
  name                = "nsg-mgmt-pri${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tags                = local.tags

  law_resource_id                     = module.law_central.id
  network_watcher_name                = var.network_watcher_name_r1
  network_watcher_resource_group_name = var.network_watcher_resource_group_name
  trafficAnalyticsWorkspaceId         = module.law_central.id
  trafficAnalyticsWorkspaceGuid       = module.law_central.workspace_id
  trafficAnalyticsWorkspaceRegion     = module.law_central.location
  flowLogStorageAccountId             = module.storage_account_flow_logs_r1.id
  security_rules = [
    {
      name                       = "allow-ssh"
      description                = "Allow SSH from trusted IP"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = [var.trusted_ip]
      destination_address_prefix = "*"
    }
  ]
}

module "vnet_mgmt" {
  depends_on = [module.nsg_mgmt_pri]

  source              = "./.terraform/modules/virtual-network"
  name                = "vnetmgmt${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name

  # Add additional tag to use in Azure Policy demonstration
  tags = merge(local.tags, { env = "prod" })

  law_resource_id = module.law_central.id
  address_space_vnet                = ["10.250.0.0/16"]
  subnets = [
    {
      name                 = "snet-pri"
      address_prefixes     = ["10.250.0.0/24"]
      network_security_group_id = module.nsg_mgmt_pri.id
    }
  ]
}

module "vm1_mgmt_r1" {
  depends_on = [
    module.vnet_mgmt
  ]

  source              = "./.terraform/modules/virtual-machine/ubuntu-server"
  name                = "vm1mgmt${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name

  subnet_id           = module.vnet_mgmt.subnets[index(module.vnet_mgmt.subnets.*.name, "snet-pri")].id
  public_ip_address_id = module.pip_vm1_mgmt.id

  vm_size             = "Standard_DC1s_v3"
  image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  identities = {
    type          = "UserAssigned"
    identity_ids  = [module.umi_ama.id]
  }
  admin_username      = var.vm_username
  admin_password      = var.vm_password
  tags                = local.tags
}

module "vm2_mgmt_r1" {
  depends_on = [
    module.vnet_mgmt
  ]

  source              = "./.terraform/modules/virtual-machine/ubuntu-server"
  name                = "vm2mgmt${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name

  subnet_id           = module.vnet_mgmt.subnets[index(module.vnet_mgmt.subnets.*.name, "snet-pri")].id
  public_ip_address_id = module.pip_vm2_mgmt.id

  vm_size             = "Standard_DC1s_v3"
  image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  identities = {
    type          = "UserAssigned"
    identity_ids  = [module.umi_ama.id]
  }
  admin_username      = var.vm_username
  admin_password      = var.vm_password
  tags                = local.tags
}

###################################################################
# Create the the Network Security Groups used in the lab
#
###################################################################

module "nsgp_pri_r1" {
  depends_on = [
    module.law_central,
    module.storage_account_flow_logs_r1,
    module.pip_vm1_mgmt
  ]

  source              = "./.terraform/modules/network-security-group"
  name                = "nsgp-pri-r1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_p.name
  tags                = local.tags

  law_resource_id                     = module.law_central.id
  network_watcher_name                = var.network_watcher_name_r1
  network_watcher_resource_group_name = var.network_watcher_resource_group_name
  trafficAnalyticsWorkspaceId         = module.law_central.id
  trafficAnalyticsWorkspaceGuid       = module.law_central.workspace_id
  trafficAnalyticsWorkspaceRegion     = module.law_central.location
  flowLogStorageAccountId             = module.storage_account_flow_logs_r1.id
  security_rules = [
    {
      name                       = "allow-ssh"
      description                = "Allow SSH from trusted IP"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = [module.pip_vm1_mgmt.ip_address]
      destination_address_prefix = "*"
    },
    {
      name                       = "block-all"
      description                = "Block all traffic"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "block-dns-service"
      description                = "Block DNS traffic to DNS service"
      priority                   = 2100
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "53"
      source_address_prefix      = "*"
      destination_address_prefix = "1.1.1.1"
    }
  ]
}

module "nsgp_pri_r2" {
  depends_on = [
    module.law_central,
    module.storage_account_flow_logs_r2,
    module.pip_vm1_mgmt
  ]

  source              = "./.terraform/modules/network-security-group"
  name                = "nsgp-pri-r2${random_string.unique.result}"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_p.name
  tags                = local.tags

  law_resource_id                     = module.law_central.id
  network_watcher_name                = var.network_watcher_name_r2
  network_watcher_resource_group_name = var.network_watcher_resource_group_name
  trafficAnalyticsWorkspaceId         = module.law_central.id
  trafficAnalyticsWorkspaceGuid       = module.law_central.workspace_id
  trafficAnalyticsWorkspaceRegion     = module.law_central.location
  flowLogStorageAccountId             = module.storage_account_flow_logs_r2.id
  security_rules = [
    {
      name                       = "allow-ssh"
      description                = "Allow SSH from trusted IP"
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = [module.pip_vm1_mgmt.ip_address]
      destination_address_prefix = "*"
    },
    {
      name                       = "block-all"
      description                = "Block all traffic"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "block-dns-service"
      description                = "Block DNS traffic to DNS service"
      priority                   = 2100
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "53"
      source_address_prefix      = "*"
      destination_address_prefix = "1.1.1.1"
    }
  ]
}

module "nsgs_pri_r1" {
  depends_on = [
    module.law_central,
    module.storage_account_flow_logs_r1,
    module.pip_vm1_mgmt
  ]

  source              = "./.terraform/modules/network-security-group"
  name                = "nsgs-pri-r1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_s.name
  tags                = local.tags

  law_resource_id                     = module.law_central.id
  network_watcher_name                = var.network_watcher_name_r1
  network_watcher_resource_group_name = var.network_watcher_resource_group_name
  trafficAnalyticsWorkspaceId         = module.law_central.id
  trafficAnalyticsWorkspaceGuid       = module.law_central.workspace_id
  trafficAnalyticsWorkspaceRegion     = module.law_central.location
  flowLogStorageAccountId             = module.storage_account_flow_logs_r1.id
  security_rules = [
    {
      name                       = "allow-ssh"
      description                = "Allow SSH from trusted IP"
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = [module.pip_vm1_mgmt.ip_address]
      destination_address_prefix = "*"
    },
    {
      name                       = "block-all"
      description                = "Block all traffic"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "block-dns-service"
      description                = "Block DNS traffic to DNS service"
      priority                   = 2100
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "53"
      source_address_prefix      = "*"
      destination_address_prefix = "1.1.1.1"
    }
  ]
}

module "nsgnp_pri_r1" {
  depends_on = [
    module.law_central,
    module.storage_account_flow_logs_r1
  ]

  source              = "./.terraform/modules/network-security-group"
  name                = "nsgnp-pri-r1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_np.name
  tags                = local.tags

  law_resource_id                     = module.law_central.id
  network_watcher_name                = var.network_watcher_name_r1
  network_watcher_resource_group_name = var.network_watcher_resource_group_name
  trafficAnalyticsWorkspaceId         = module.law_central.id
  trafficAnalyticsWorkspaceGuid       = module.law_central.workspace_id
  trafficAnalyticsWorkspaceRegion     = module.law_central.location
  flowLogStorageAccountId             = module.storage_account_flow_logs_r1.id
  security_rules = [
    {
      name                       = "allow-ssh"
      description                = "Allow SSH from trusted IP"
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = [module.pip_vm1_mgmt.ip_address]
      destination_address_prefix = "*"
    },
    {
      name                       = "block-all"
      description                = "Block all traffic"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "block-dns-service"
      description                = "Block DNS traffic to DNS service"
      priority                   = 2100
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "53"
      source_address_prefix      = "*"
      destination_address_prefix = "1.1.1.1"
    }
  ]
}

module "nsgnp_pri_r2" {
  depends_on = [
    module.law_central,
    module.storage_account_flow_logs_r1,
    module.pip_vm1_mgmt
  ]

  source              = "./.terraform/modules/network-security-group"
  name                = "nsgnp-pri-r2${random_string.unique.result}"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_np.name
  tags                = local.tags

  law_resource_id                     = module.law_central.id
  network_watcher_name                = var.network_watcher_name_r2
  network_watcher_resource_group_name = var.network_watcher_resource_group_name
  trafficAnalyticsWorkspaceId         = module.law_central.id
  trafficAnalyticsWorkspaceGuid       = module.law_central.workspace_id
  trafficAnalyticsWorkspaceRegion     = module.law_central.location
  flowLogStorageAccountId             = module.storage_account_flow_logs_r2.id
  security_rules = [
    {
      name                       = "allow-ssh"
      description                = "Allow SSH from trusted IP"
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = [module.pip_vm1_mgmt.ip_address]
      destination_address_prefix = "*"
    },
    {
      name                       = "block-all"
      description                = "Block all traffic"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "block-dns-service"
      description                = "Block DNS traffic to DNS service"
      priority                   = 2100
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "53"
      source_address_prefix      = "*"
      destination_address_prefix = "1.1.1.1"
    }
  ]
}

###################################################################
# Create the virtual networks used in the lab
#
###################################################################

module "vnetp_r1" {
  depends_on = [module.nsgp_pri_r1]

  source              = "./.terraform/modules/virtual-network"
  name                = "vnetp-r1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_p.name

  # Add additional tag to use in Azure Policy demonstration
  tags = merge(local.tags, { env = "prod" })

  law_resource_id = module.law_central.id
  address_space_vnet                = ["10.0.0.0/16"]
  subnets = [
    {
      name                 = "snet-pri"
      address_prefixes     = ["10.0.0.0/24"]
      network_security_group_id = module.nsgp_pri_r1.id
    }
  ]
}

module "vnetp_r2" {
  depends_on = [module.nsgp_pri_r2]

  source              = "./.terraform/modules/virtual-network"
  name                = "vnetp-r2${random_string.unique.result}"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_p.name

  # Add additional tag to use in Azure Policy demonstration
  tags = merge(local.tags, { env = "prod" })

  law_resource_id = module.law_central.id
  address_space_vnet                = ["10.10.0.0/16"]
  subnets = [
    {
      name                 = "snet-pri"
      address_prefixes     = ["10.10.0.0/24"]
      network_security_group_id = module.nsgp_pri_r2.id
    }
  ]
}

module "vnets_r1" {
  depends_on = [module.nsgs_pri_r1]

  source              = "./.terraform/modules/virtual-network"
  name                = "vnets-r1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_s.name
  tags                = local.tags

  law_resource_id = module.law_central.id
  address_space_vnet                = ["10.30.0.0/16"]
  subnets = [
    {
      name                 = "snet-pri"
      address_prefixes     = ["10.30.0.0/24"]
      network_security_group_id = module.nsgs_pri_r1.id
    }
  ]
}

module "vnetnp_r1" {
  depends_on = [module.nsgnp_pri_r1]

  source              = "./.terraform/modules/virtual-network"
  name                = "vnetnp-r1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_np.name

  # Add additional tag to use in Azure Policy demonstration
  tags = merge(local.tags, { env = "nonprod" })

  law_resource_id = module.law_central.id
  address_space_vnet                = ["10.100.0.0/16"]
  subnets = [
    {
      name                 = "snet-pri"
      address_prefixes     = ["10.100.0.0/24"]
      network_security_group_id = module.nsgnp_pri_r1.id
    }
  ]
}

module "vnetnp_r2" {
  depends_on = [module.nsgnp_pri_r2]

  source              = "./.terraform/modules/virtual-network"
  name                = "vnetnp-r2${random_string.unique.result}"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_np.name
  # Add additional tag to use in Azure Policy demonstration
  tags = merge(local.tags, { env = "nonprod" })

  law_resource_id = module.law_central.id
  address_space_vnet                = ["10.110.0.0/16"]
  subnets = [
    {
      name                 = "snet-pri"
      address_prefixes     = ["10.110.0.0/24"]
      network_security_group_id = module.nsgnp_pri_r2.id
    }
  ]
}

###################################################################
# Create the central virtual network manager and its components
#
###################################################################

module "avnm_central" {
  depends_on = [azurerm_resource_group.rg_mgmt]

  source              = "./.terraform/modules/network-manager/manager"
  name                = "avnm-central${random_string.unique.result}"
  description = "The virtual network manager for the central IT team"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tags = local.tags

  law_resource_id = module.law_central.id
  configurations_supported = ["SecurityAdmin"]
  management_scope = {
    management_group_ids = [var.management_group_id]
  }
}

module "security_config_central" {
  depends_on = [module.avnm_central]

  source              = "./.terraform/modules/network-manager/security-config"
  name                = "cfg-sec-prod"
  description = "The security configuration for the production environment"

  network_manager_id = module.avnm_central.id
  apply_on_network_intent_policy_based_services = ["AllowRulesOnly"]
}

module "network_group_central_prod" {
  depends_on = [module.avnm_central]

  source              = "./.terraform/modules/network-manager/network-group"
  name                = "ng-prod"
  description = "The Network Group for all production virtual networks"

  network_manager_id = module.avnm_central.id
}

module "network_group_central_nonprod" {
  depends_on = [module.avnm_central]

  source              = "./.terraform/modules/network-manager/network-group"
  name                = "ng-nonprod"
  description = "The Network Group for all non-production virtual networks"

  network_manager_id = module.avnm_central.id
}

module "network_group_central_sensitive" {
  depends_on = [module.avnm_central]

  source              = "./.terraform/modules/network-manager/network-group"
  name                = "ng-sensitive"
  description = "The Network Group for all sensitive virtual networks"

  network_manager_id = module.avnm_central.id
}

module "network_group_central_prod_members" {
  depends_on = [
    module.network_group_central_prod,
    module.vnetp_r1,
    module.vnetp_r2,
    module.vnets_r1
    ]

  source              = "./.terraform/modules/network-manager/static-member"
  members               = [
    module.vnetp_r1.id, 
    module.vnetp_r2.id, 
    module.vnets_r1.id ]

  network_group_id = module.network_group_central_prod.id
}

module "network_group_central_sensitive_members" {
  depends_on = [
    module.network_group_central_sensitive,
    module.vnets_r1
    ]

  source              = "./.terraform/modules/network-manager/static-member"
  members               = [
    module.vnets_r1.id ]

  network_group_id = module.network_group_central_sensitive.id
}

module "network_group_central_nonprod_members" {
  depends_on = [
    module.network_group_central_nonprod,
    module.vnetnp_r1,
    module.vnetnp_r2
    ]

  source              = "./.terraform/modules/network-manager/static-member"
  members               = [
    module.vnetnp_r1.id, 
    module.vnetnp_r2.id
 ]

  network_group_id = module.network_group_central_nonprod.id
}

module "security_rule_collection_central_prod" {
  depends_on = [
    module.network_group_central_prod_members,
    module.network_group_central_sensitive_members
  ]

  source              = "./.terraform/modules/network-manager/security-admin-rule-collection"
  name                = "rc-prod"
  security_configuration_id = module.security_config_central.id
  network_group_id = [
    module.network_group_central_prod.id,
    module.network_group_central_sensitive.id
  ]
}

module "security_rule_collection_central_sensitive" {
  depends_on = [
    module.network_group_central_sensitive_members
  ]

  source              = "./.terraform/modules/network-manager/security-admin-rule-collection"
  name                = "rc-sensitive"
  security_configuration_id = module.security_config_central.id
  network_group_id = [
    module.network_group_central_sensitive.id
  ]
}

module "security_rule_collection_central_nonprod" {
  depends_on = [
    module.network_group_central_nonprod_members
  ]

  source              = "./.terraform/modules/network-manager/security-admin-rule-collection"
  name                = "rc-nonprod"
  security_configuration_id = module.security_config_central.id
  network_group_id = [
    module.network_group_central_nonprod.id
  ]
}

module "security_rules_central_prod" {
  depends_on = [
    module.security_rule_collection_central_prod
  ]

  source              = "./.terraform/modules/network-manager/security-admin-rule"
  security_rule_collection_id = module.security_rule_collection_central_prod.id
  security_rules = [
      {
      name                       = "AlwaysAllowDns"
      description                = "Always allow DNS traffic to DNS service"
      priority                   = 1000
      direction                  = "Outbound"
      action                     = "AlwaysAllow"
      protocol                   = "Any"
      source_port_ranges         = ["0-65535"]
      destination_port_ranges    = ["53"]
      source = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
      destination = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "1.1.1.1/32"
        }
      ]
    },
    {
      name                       = "AllowSSHFromTrustedNetwork"
      description                = "Allow SSH from trusted network"
      priority                   = 2000
      direction                  = "Inbound"
      action                     = "Allow"
      protocol                   = "Tcp"
      source_port_ranges         = ["0-65535"]
      destination_port_ranges    = ["22"]
      source = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = module.pip_vm1_mgmt.ip_address
        }
      ]
      destination = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
    },
    {
      name                       = "DenySshFromAll"
      description                = "BlockSshFromAll"
      priority                   = 3000
      direction                  = "Inbound"
      action                     = "Deny"
      protocol                   = "Tcp"
      source_port_ranges         = ["0-65535"]
      destination_port_ranges    = ["22"]
      source = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
      destination = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
    }
  ]
}

module "security_rules_central_nonprod" {
  depends_on = [
    module.security_rule_collection_central_nonprod
  ]

  source              = "./.terraform/modules/network-manager/security-admin-rule"
  security_rule_collection_id = module.security_rule_collection_central_nonprod.id
  security_rules = [
      {
      name                       = "AlwaysAllowDns"
      description                = "Always allow DNS traffic to DNS service"
      priority                   = 1100
      direction                  = "Outbound"
      action                     = "AlwaysAllow"
      protocol                   = "Any"
      source_port_ranges         = ["0-65535"]
      destination_port_ranges    = ["53"]
      source = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
      destination = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "1.1.1.1/32"
        }
      ]
    },
    {
      name                       = "AllowSSHFromTrustedNetwork"
      description                = "Allow SSH from trusted network"
      priority                   = 2100
      direction                  = "Inbound"
      action                     = "Allow"
      protocol                   = "Tcp"
      source_port_ranges         = ["0-65535"]
      destination_port_ranges    = ["22"]
      source = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = module.pip_vm1_mgmt.ip_address
        }
      ]
      destination = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
    },
    {
      name                       = "DenySshFromAll"
      description                = "BlockSshFromAll"
      priority                   = 3100
      direction                  = "Inbound"
      action                     = "Deny"
      protocol                   = "Tcp"
      source_port_ranges         = ["0-65535"]
      destination_port_ranges    = ["22"]
      source = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
      destination = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
    }
  ]
}

module "security_rules_central_sensitive" {
  depends_on = [
    module.security_rule_collection_central_sensitive
  ]

  source              = "./.terraform/modules/network-manager/security-admin-rule"
  security_rule_collection_id = module.security_rule_collection_central_sensitive.id
  security_rules = [
    {
      name                       = "DenyHttp"
      description                = "Deny all HTTP traffic"
      priority                   = 3010
      direction                  = "Inbound"
      action                     = "Deny"
      protocol                   = "Tcp"
      source_port_ranges         = ["0-65535"]
      destination_port_ranges    = ["80"]
      source = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
      destination = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
    }
  ]
}

###################################################################
# Create the business virtual network manager and its components
#
###################################################################


module "avnm_bu" {
  depends_on = [azurerm_resource_group.rg_mgmt]

  source              = "./.terraform/modules/network-manager/manager"
  name                = "avnm-bu${random_string.unique.result}"
  description = "The virtual network manager for the business unit"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_mgmt.name
  tags = local.tags

  law_resource_id = module.law_central.id
  configurations_supported = ["SecurityAdmin"]
  management_scope = {
    subscription_ids = [data.azurerm_subscription.current_subscription.id]
  }
}

module "security_config_bu" {
  depends_on = [module.avnm_central]

  source              = "./.terraform/modules/network-manager/security-config"
  name                = "cfg-sec-prod"
  description = "The security configuration for the production environment"

  network_manager_id = module.avnm_bu.id
  apply_on_network_intent_policy_based_services = ["AllowRulesOnly"]
}

module "network_group_bu_prod" {
  depends_on = [module.avnm_central]

  source              = "./.terraform/modules/network-manager/network-group"
  name                = "ng-prod"
  description = "The Network Group for all production virtual networks"

  network_manager_id = module.avnm_bu.id
}

module "network_group_bu_nonprod" {
  depends_on = [module.avnm_central]

  source              = "./.terraform/modules/network-manager/network-group"
  name                = "ng-nonprod"
  description = "The Network Group for all non-production virtual networks"

  network_manager_id = module.avnm_bu.id
}

module "network_group_bu_prod_members" {
  depends_on = [
    module.network_group_bu_prod,
    module.vnetp_r1,
    module.vnetp_r2,
    module.vnets_r1
  ]

  source              = "./.terraform/modules/network-manager/static-member"
  members               = [
    module.vnetp_r1.id, 
    module.vnetp_r2.id, 
    module.vnets_r1.id 
  ]

  network_group_id = module.network_group_bu_prod.id
}

module "network_group_bu_nonprod_members" {
  depends_on = [
    module.network_group_bu_nonprod,
    module.vnetnp_r1,
    module.vnetnp_r2
  ]

  source              = "./.terraform/modules/network-manager/static-member"
  members               = [
    module.vnetnp_r1.id,
    module.vnetnp_r2.id
  ]

  network_group_id = module.network_group_bu_nonprod.id
}

module "security_rule_collection_bu_prod" {
  depends_on = [
    module.network_group_bu_prod_members
  ]

  source              = "./.terraform/modules/network-manager/security-admin-rule-collection"
  name                = "rc-prod"
  security_configuration_id = module.security_config_bu.id
  network_group_id = [
    module.network_group_bu_prod.id
  ]
}

module "security_rules_bu_prod" {
  depends_on = [
    module.security_rule_collection_bu_prod
  ]

  source              = "./.terraform/modules/network-manager/security-admin-rule"
  security_rule_collection_id = module.security_rule_collection_bu_prod.id
  security_rules = [
      {
      name                       = "AllowSshFromAll"
      description                = "Always allow SSH from all"
      priority                   = 1000
      direction                  = "Inbound"
      action                     = "AlwaysAllow"
      protocol                   = "Tcp"
      source_port_ranges         = ["0-65535"]
      destination_port_ranges    = ["22"]
      source = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
      destination = [
        {
          address_prefix_type = "IPPrefix"
          address_prefix      = "*"
        }
      ]
    }
  ]
}

###################################################################
# Create public ips for virtual machines
#
###################################################################

module "pip_p_vm_r1" {
  depends_on = [ 
    azurerm_resource_group.rg_p,
    module.law_central
  ]

  source              = "./.terraform/modules/public-ip"
  name                = "pipvmpr1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_p.name

  law_resource_id = module.law_central.id
  tags                = local.tags
}

module "pip_np_vm_r1" {
  depends_on = [ 
    azurerm_resource_group.rg_np,
    module.law_central
  ]

  source              = "./.terraform/modules/public-ip"
  name                = "pipvmnpr1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_np.name

  law_resource_id = module.law_central.id
  tags                = local.tags
}

module "pip_s_vm_r1" {
  depends_on = [ 
    azurerm_resource_group.rg_s,
    module.law_central
  ]

  source              = "./.terraform/modules/public-ip"
  name                = "pipvmsr1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_s.name

  law_resource_id = module.law_central.id
  tags                = local.tags
}

###################################################################
# Create virtual machines
#
###################################################################

module "vm_p_r1" {
  depends_on = [
    module.vnetp_r1,
    module.pip_p_vm_r1
  ]

  source              = "./.terraform/modules/virtual-machine/ubuntu-server"
  name                = "vmpr1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_p.name

  subnet_id           = module.vnetp_r1.subnets[index(module.vnetp_r1.subnets.*.name, "snet-pri")].id
  public_ip_address_id = module.pip_p_vm_r1.id

  vm_size             = "Standard_DC1s_v3"
  image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  identities = {
    type          = "UserAssigned"
    identity_ids  = [module.umi_ama.id]
  }
  admin_username      = var.vm_username
  admin_password      = var.vm_password
  tags                = local.tags
}

module "vm_np_r1" {
  depends_on = [
    module.vnetnp_r1,
    module.pip_np_vm_r1
  ]

  source              = "./.terraform/modules/virtual-machine/ubuntu-server"
  name                = "vmnpr1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_np.name

  subnet_id           = module.vnetnp_r1.subnets[index(module.vnetnp_r1.subnets.*.name, "snet-pri")].id
  public_ip_address_id = module.pip_np_vm_r1.id

  vm_size             = "Standard_DC1s_v3"
  image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  identities = {
    type          = "UserAssigned"
    identity_ids  = [module.umi_ama.id]
  }
  admin_username      = var.vm_username
  admin_password      = var.vm_password
  tags                = local.tags
}

module "vm_s_r1" {
  depends_on = [
    module.vnets_r1,
    module.pip_s_vm_r1
  ]

  source              = "./.terraform/modules/virtual-machine/ubuntu-server"
  name                = "vmsr1${random_string.unique.result}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_s.name

  subnet_id           = module.vnets_r1.subnets[index(module.vnets_r1.subnets.*.name, "snet-pri")].id
  public_ip_address_id = module.pip_s_vm_r1.id

  vm_size             = "Standard_DC1s_v3"
  image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  identities = {
    type          = "UserAssigned"
    identity_ids  = [module.umi_ama.id]
  }
  admin_username      = var.vm_username
  admin_password      = var.vm_password
  tags                = local.tags
}