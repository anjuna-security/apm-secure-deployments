resource "azurerm_key_vault" "apm" {
  name                       = "apmkv${random_string.random.result}"
  location                   = azurerm_resource_group.apm.location
  resource_group_name        = azurerm_resource_group.apm.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7
  enabled_for_deployment     = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "Purge",
      "SetIssuers",
      "Update",
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Delete",
      "Encrypt",
      "Get",
      "GetRotationPolicy",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "SetRotationPolicy",
      "Sign",
      "Update",
      "Verify",
      "WrapKey",
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.apm.principal_id

    key_permissions = [
      "Release"
    ]

    secret_permissions = [
      "Get",
      "Set"
    ]
  }
}
