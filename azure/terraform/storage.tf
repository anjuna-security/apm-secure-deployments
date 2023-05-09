# defines a storage account 
resource "azurerm_storage_account" "apm" {
  name                = "apmsa${random_string.random.result}"
  resource_group_name = azurerm_resource_group.apm.name
  location            = azurerm_resource_group.apm.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "apm" {
  name                 = "apmsac${random_string.random.result}"
  storage_account_name = azurerm_storage_account.apm.name
}

resource "azurerm_key_vault_secret" "sa_access_key" {
  name         = "apm-key-${random_string.random.result}"
  value        = azurerm_storage_account.apm.primary_access_key
  key_vault_id = azurerm_key_vault.apm.id
}
