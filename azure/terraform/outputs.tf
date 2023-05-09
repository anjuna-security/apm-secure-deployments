output "group_name" {
    value = azurerm_resource_group.apm.name
}

output "storage_account_name" {
    value = azurerm_storage_account.apm.name
}

output "storage_account_container_name" {
    value = azurerm_storage_container.apm.name
}

output "apm_identity_id" {
    value = azurerm_user_assigned_identity.apm.id
}

output "apm_key_vault_name" {
    value = azurerm_key_vault.apm.name
}

output "apm_hostname" {
    value = var.apm_hostname
}

output "apm_port" {
    value = var.apm_port
}

output "apm_location" {
    value = var.location
}

output "apm_image_gallery_name" {
    value = azurerm_shared_image_gallery.apm.name
}

output "apm_image_definition_name" {
    value = azurerm_shared_image.apm.name
}

output "apm_image_definition_id" {
    value = azurerm_shared_image.apm.id
}

output "apm_nic_name" {
    value = azurerm_network_interface.apm.name
}

output "apm_public_ip" {
    value = azurerm_public_ip.apm.ip_address
}

output "apm_private_ip" {
    value = azurerm_network_interface.apm.private_ip_address
}

output "apm_image_version" {
    value = var.apm_image_version   
}

output "apm_master_key_name" {
    value = var.apm_master_key_name
}

output "maa_endpoint" {
    value = azurerm_attestation_provider.apm.attestation_uri
}

output "apm_vnet_name" {
    value = azurerm_virtual_network.apm.name
}

output "apm_subnet_name" {
    value = azurerm_subnet.apm.name
}