# defines a user managed identity to enable integration with other azure services
resource "azurerm_user_assigned_identity" "apm" {
  name                = "apm"
  resource_group_name = azurerm_resource_group.apm.name
  location            = azurerm_resource_group.apm.location
}
