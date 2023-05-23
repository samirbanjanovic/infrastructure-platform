terraform {
    required_providers {
        azurerm = {
        source  = "hashicorp/azurerm"
        version = ">=3.0.0"
        }
    }
}

provider "azurerm" {
    features {}
}

locals {
  suffix               = var.unique_suffis ? "-${random_string.rand.result}" : ""
  resource_group_name  = "${var.resource_group_name}${local.suffix}"
  control_plane_name   = "${var.control_plane_name}${local.suffix}"
  appstate_sa_name     = "${var.appstate_sa_name}${random_string.rand.result}"
}

resource "random_string" "rand" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "capi" {
  name     = local.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "capi" {
  name                = "logs-${var.cluster_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.capi.name
  retention_in_days   = 30
}

# create the aks cluster that'll be used to manage the other clusters
resource "azurerm_kubernetes_cluster" "capi" {
  name                = local.control_plane_name
  location            = azurerm_resource_group.capi.location
  resource_group_name = azurerm_resource_group.capi.name
  dns_prefix          = local.control_plane_name
  kubernetes_version  = var.kubernetes_version
  node_resource_group = "${local.control_plane_name}-nodes"
  
  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_d2as_v5"
    vnet_subnet_id = azurerm_virtual_network.default.subnet.*.id[0]
    upgrade_settings {
      max_surge = 1
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # turn on container insights
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.capi.id
  }

  tags = {
    Type     = "Cluster Manager"
    Workload = "CAPI"
  }
}

# see https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-custom-metrics?tabs=cli#enable-custom-metrics
# The preview feature for role assignment this will be added automatically.
# For now we need to add it manually.
# The id is hard to find, it is part of the "oms_agent" output attribute and was moved from addon_profiles in the later version of the providers.
# Use object_id and specify check AAD otherwise it will go into an infinite loop.
# https://github.com/hashicorp/terraform-provider-azurerm/pull/7056
resource "azurerm_role_assignment" "omsagent-aks" {
  scope                            = azurerm_kubernetes_cluster.capi.id
  role_definition_name             = "Monitoring Metrics Publisher"
  principal_id                     = azurerm_kubernetes_cluster.capi.oms_agent[0].oms_agent_identity[0].object_id
  skip_service_principal_aad_check = false
}