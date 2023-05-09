# defines a user managed identity to enable integration with other azure services
resource "azurerm_user_assigned_identity" "apm" {
  name                = "apm"
  resource_group_name = azurerm_resource_group.apm.name
  location            = azurerm_resource_group.apm.location
}

# allows the APM CVM to persist data to the storage account
resource "azurerm_role_assignment" "sa_access" {
  scope                = azurerm_storage_account.apm.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.apm.principal_id
}