provider "azurerm" {
  features {}
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.50"
    }
  }
}

# identifies the user running the terraform script
data "azurerm_client_config" "current" {}

# defines a random string to be used as a suffix for all resources
# to avoid conflicts with other terraform scripts running in parallel
# by other users
resource "random_string" "random" {
  length  = 5
  special = false
  upper   = false
}

# defines an unique resource group to store all resources
# name can be overridden by the user with the group_name variable
resource "azurerm_resource_group" "apm" {
  name     = var.group_name != "" ? var.group_name : "apm-${random_string.random.result}"
  location = var.location
}

# defines an MAA endpoint
resource "azurerm_attestation_provider" "apm" {
  name                = "apm${random_string.random.result}"
  resource_group_name = azurerm_resource_group.apm.name
  location            = var.location
}
