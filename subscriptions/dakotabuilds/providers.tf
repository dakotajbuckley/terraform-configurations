terraform {
    required_providers {
      azurerm = {
        source = "hashicorp/azurerm"
      }
      azuread = {
        source = "hashicorp/azuread"
      }
      argocd = {
        source = "argoproj-labs/argocd"
        version = "7.15.3"
      }
      databricks = {
        source = "databricks/databricks"
      }
    }

    backend "azurerm" {
      tenant_id = "6afe2c08-005f-4f3b-8ac3-99458dd7a365"
      resource_group_name = "dakotabuilds-rg"
      storage_account_name = "dakotabuilds"
      container_name = "dakotabuilds-terraform-state"
      key = "dakotabuilds-terraform-state"
    }
}

provider "argocd" {
  server_addr = "winserv-001:30001"
  username = "admin"
  password = "Indiana1985Jones!"
  insecure = true
}

provider "azurerm" {
    features {
      
    }
}

