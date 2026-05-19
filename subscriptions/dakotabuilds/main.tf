data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "dakotabuilds-rg" {
  name     = "dakotabuilds-rg"
  location = "westus2"
}

resource "azurerm_resource_group" "dakotabuilds-denmark-rg" {
  name     = "dakotabuilds-denmark-rg"
  location = "denmarkeast"
}

resource "azurerm_storage_account" "dakotabuilds" {
  name                     = "dakotabuilds"
  resource_group_name      = azurerm_resource_group.dakotabuilds-rg.name
  location                 = azurerm_resource_group.dakotabuilds-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "dakotabuild-terraform-state" {
  name                  = "dakotabuilds-terraform-state"
  storage_account_id    = azurerm_storage_account.dakotabuilds.id
  container_access_type = "private"
}

resource "azurerm_dns_zone" "dakotabuilds-dns-zone" {
  name                = "dakotabuilds.dev"
  resource_group_name = azurerm_resource_group.dakotabuilds-rg.name
}

resource "azurerm_dns_a_record" "test" {
  name                = "test"
  zone_name           = azurerm_dns_zone.dakotabuilds-dns-zone.name
  resource_group_name = azurerm_dns_zone.dakotabuilds-dns-zone.resource_group_name
  ttl                 = 300
  records             = ["76.149.229.188"]
}

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

resource "azurerm_role_assignment" "external-secrets-kv" {
    scope = azurerm_key_vault.dakotabuilds-kv.id
    role_definition_name = "Key Vault Secrets User"
    principal_id = azuread_application.k8s-external-secrets.client_id
}

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

# Creates an NSG with what ever security rules you specify. Then will assocate that NSG with as many subnets as you'd like through IDs
module "azure_network_security_group" {
  source                      = "../../modules/azure_network_security_group"
  network_security_group_name = "dakotabuilds-nsg-01"
  location                    = azurerm_resource_group.dakotabuilds-rg.location
  resource_group_name         = azurerm_resource_group.dakotabuilds-rg.name
  subnet_ids_to_associate     = [for key, value in module.azure_virtual_network.subnet_ids : value]
  security_rules = {
    "allow-web-traffic" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["80", "443", "22"]
      source_address_prefixes    = ["76.149.229.188/32"]
      destination_address_prefix = "*"
    }
  }
}

module "azure_virtual_network_denmark" {
  source              = "../../modules/azure_virtual_network"
  resource_group_name = azurerm_resource_group.dakotabuilds-denmark-rg.name
  location            = azurerm_resource_group.dakotabuilds-denmark-rg.location
  vnet_name           = "dakotabuilds-denmark-vnet"
  vnet_address_space  = ["10.10.0.0/16"]
  subnets = {
    "dakotabuilds-denmark-snet-01" = ["10.10.10.0/24"]
  }
}

module "azure_network_security_group_denmark" {
  source                      = "../../modules/azure_network_security_group"
  network_security_group_name = "dakotabuilds-denmark-nsg-01"
  location                    = azurerm_resource_group.dakotabuilds-denmark-rg.location
  resource_group_name         = azurerm_resource_group.dakotabuilds-denmark-rg.name
  subnet_ids_to_associate     = [for key, value in module.azure_virtual_network_denmark.subnet_ids : value]
  security_rules = {
    "allow-web-traffic" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["80", "443", "22"]
      source_address_prefixes    = ["76.149.229.188/32"]
      destination_address_prefix = "*"
    }
  }
}

# module "azure_linux_virtual_machine_denmark" {
#     source = "../../modules/azure_linux_virtual_machine"
#     resource_group_name = azurerm_resource_group.dakotabuilds-denmark-rg.name
#     location = "denmarkeast"
#     nic_name = "dakotabuilds-nic"
#     public_ip_name = "dakotabuilds-pip1"
#     admin_username = "dakotab"
#     subnet_id = module.azure_virtual_network_denmark.subnet_ids.dakotabuilds-denmark-snet-01
#     virtual_machine_name = "dakotabuilds-vm"
# }
