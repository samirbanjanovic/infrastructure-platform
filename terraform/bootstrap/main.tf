# pin the version of the terrform azurerm provider
# this can be updated as new versions are tested
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.35.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Get the data for the client configuration. This includes subscription information needed to create resources
data "azurerm_client_config" "current" {}

# this random string is used to get a unique storage account name
# NOTE: terraform state is not saved so this will generate a unique account name each execution
resource "random_string" "tfstate" {
  length  = 5
  special = false
  upper   = false
}

# Create variables that parameterize this run
variable "name" {
  type    = string
  default = "clustercontrol"
}

variable "location" {
  type    = string
  default = "eastus"
}

# Create a Resource Group
resource "azurerm_resource_group" "tfstate" {
  name     = "${var.name}-tfstate"
  location = var.location
}

# Use the resource group to create a storage account.
# This storage account will hold the terraform state for the main terraform scripts in the /terraform root directory
resource "azurerm_storage_account" "tfstate" {
  name                     = "${var.name}tfstate${random_string.tfstate.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create a tfstate storage container per documentation here: 
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}