# RESOURCE GROUPS

resource "azurerm_resource_group" "dakotabuilds-rg" {
  name     = "dakotabuilds-rg"
  location = "westus2"
}

# STORAGE ACCOUNTS

resource "azurerm_storage_account" "dakotabuilds" {
  name                     = "dakotabuilds"
  resource_group_name      = azurerm_resource_group.dakotabuilds-rg.name
  location                 = azurerm_resource_group.dakotabuilds-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account" "dakotabuilds-databricks" {
  name = "dakotabuildsdatabricks"
  resource_group_name      = azurerm_resource_group.dakotabuilds-rg.name
  location                 = azurerm_resource_group.dakotabuilds-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled = true
}

# STORAGE CONTAINERS

resource "azurerm_storage_container" "dakotabuild-terraform-state" {
  name                  = "dakotabuilds-terraform-state"
  storage_account_id    = azurerm_storage_account.dakotabuilds.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "dakotabuild-databricks-containers" {
  name                  = "dakotabuilds-databricks-container"
  storage_account_id    = azurerm_storage_account.dakotabuilds-databricks.id
  container_access_type = "private"
}

# ROLE ASSIGNMENTS

resource "azurerm_role_assignment" "dakotabuilds-access-connector-to-container" {
  scope = azurerm_storage_container.dakotabuild-databricks-containers.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id = azurerm_databricks_access_connector.dakotabuilds_databricks_access_connector.identity[0].principal_id
}

# DNS ZONES

resource "azurerm_dns_zone" "dakotabuilds-dns-zone" {
  name                = "dakotabuilds.dev"
  resource_group_name = azurerm_resource_group.dakotabuilds-rg.name
}

# DNS ZONES

resource "azurerm_dns_a_record" "test" {
  name                = "test"
  zone_name           = azurerm_dns_zone.dakotabuilds-dns-zone.name
  resource_group_name = azurerm_dns_zone.dakotabuilds-dns-zone.resource_group_name
  ttl                 = 300
  records             = ["76.149.229.188"]
}

# KEY VAULTS

resource "azurerm_key_vault" "dakotabuilds-kv" {
  name                = "dakotabuilds-kv"
  location            = azurerm_resource_group.dakotabuilds-rg.location
  resource_group_name = azurerm_resource_group.dakotabuilds-rg.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  rbac_authorization_enabled = true
}

resource "azurerm_key_vault_access_policy" "terraform_current_user" {
  key_vault_id = azurerm_key_vault.dakotabuilds-kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Purge",
  ]
}

# KEY VAULT SECRETS

resource "azurerm_key_vault_secret" "dakotabuilds-kv-first-name" {
  name         = "first-name"
  value        = "Dakota"
  key_vault_id = azurerm_key_vault.dakotabuilds-kv.id

  depends_on = [
    azurerm_key_vault_access_policy.terraform_current_user,
  ]
}

resource "azurerm_key_vault_secret" "dakotabuilds-kv-last-name" {
  name         = "last-name"
  value        = "Buckley"
  key_vault_id = azurerm_key_vault.dakotabuilds-kv.id

  depends_on = [
    azurerm_key_vault_access_policy.terraform_current_user,
  ]
}

resource "azurerm_key_vault_secret" "dakotabuilds-kv-favorite-food" {
  name         = "favorite-food"
  value        = "Burritos"
  key_vault_id = azurerm_key_vault.dakotabuilds-kv.id

  depends_on = [
    azurerm_key_vault_access_policy.terraform_current_user,
  ]
}

# SERVICE PRINCIPALS

resource "azuread_application" "k8s-external-secrets" {
  display_name = "k8s-external-secrets"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "k8s-external-secrets" {
  client_id                    = azuread_application.k8s-external-secrets.client_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal_password" "k8s-external-secrets-password" {
    service_principal_id = azuread_service_principal.k8s-external-secrets.id
}

# DATABRICKS

resource "azurerm_databricks_workspace" "dakotabuilds-databricks-workspace" {
  name = "dakotabuilds-databricks-workspace"
  resource_group_name = azurerm_resource_group.dakotabuilds-rg.name
  location = azurerm_resource_group.dakotabuilds-rg.location
  sku = "trial"
}

resource "azurerm_databricks_access_connector" "dakotabuilds_databricks_access_connector" {
  name = "dakotabuilds_databricks_access_connector"
  resource_group_name = azurerm_resource_group.dakotabuilds-rg.name
  location = azurerm_resource_group.dakotabuilds-rg.location
  identity {
    type = "SystemAssigned"
  }
}

# MODULES

# Creates a VNet then will create as many subnets as you pass in then associate those with the vnet
module "azure_virtual_network" {
  source              = "../../modules/azure_virtual_network"
  resource_group_name = azurerm_resource_group.dakotabuilds-rg.name
  location            = azurerm_resource_group.dakotabuilds-rg.location
  vnet_name           = "dakotabuilds-vnet"
  vnet_address_space  = ["10.0.0.0/16"]
  subnets = {
    "dakotabuilds-snet-01" = ["10.0.10.0/24"]
  }
}

