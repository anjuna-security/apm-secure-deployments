# defines a storage account 
resource "azurerm_storage_account" "apm" {
  name                = "apmsa${random_string.random.result}"
  resource_group_name = azurerm_resource_group.apm.name
  location            = azurerm_resource_group.apm.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.apm.id]
    ip_rules = ["${chomp(data.http.myip.response_body)}"]
  }
}

resource "azurerm_storage_container" "apm" {
  name                 = "apmsac${random_string.random.result}"
  storage_account_name = azurerm_storage_account.apm.name
}
