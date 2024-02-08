# Configure the AzApi and AzureRm providers
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.12.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.89.0"
    }
  }
  required_version = ">= 1.7.0"
  backend "azurerm" {}
}