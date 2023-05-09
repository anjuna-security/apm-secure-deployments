# defines a vm image gallery to store the APM image
resource "azurerm_shared_image_gallery" "apm" {
  name                = "apmsig${random_string.random.result}"
  resource_group_name = azurerm_resource_group.apm.name
  location            = azurerm_resource_group.apm.location
}

# defines a vm image definition to store the APM image
resource "azurerm_shared_image" "apm" {
  name                      = "apm"
  gallery_name              = azurerm_shared_image_gallery.apm.name
  resource_group_name       = azurerm_resource_group.apm.name
  os_type                   = "Linux"
  specialized               = true
  hyper_v_generation        = "V2"
  architecture              = "x64"
  confidential_vm_supported = true
  location                  = var.location

  identifier {
    publisher = "AnjunaSecurity"
    offer     = "APM"
    sku       = "Standard"
  }
}
