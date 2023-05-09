# identifies the ip address of the user running this terraform script
# this will install basic network access rules so that the user can
# initialize the APM properly
data "http" "myip" {
  url = "https://api.ipify.org"
}

# defines a private virtual network to place the APM CVM
resource "azurerm_virtual_network" "apm" {
  name                = "apm-vnet-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.apm.name
  location            = azurerm_resource_group.apm.location
  address_space       = ["${var.base_address_prefix}.0.0/16"]
}

# defines a private subnet to place the APM CVM
resource "azurerm_subnet" "apm" {
  name                 = "apm-subnet-${random_string.random.result}"
  resource_group_name  = azurerm_resource_group.apm.name
  virtual_network_name = azurerm_virtual_network.apm.name
  address_prefixes     = ["${var.base_address_prefix}.0.0/24"]
}

# defines a network security group with rules to better control 
# communication with APM from the internet
resource "azurerm_network_security_group" "apm" {
  name                = "apm-nsg-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.apm.name
  location            = azurerm_resource_group.apm.location
}

# an inbound rule allowing communication with APM from the internet through APM's port number
resource "azurerm_network_security_rule" "apm" {
  name                        = "REST"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefixes     = ["${data.http.myip.response_body}/32","${azurerm_subnet.apm.address_prefixes[0]}"]
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "${var.apm_port}"
  resource_group_name         = azurerm_resource_group.apm.name
  network_security_group_name = azurerm_network_security_group.apm.name
}

# defines a public ip address to allow communication with APM from the internet
resource "azurerm_public_ip" "apm" {
  name                = "apm-public-ip-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.apm.name
  location            = azurerm_resource_group.apm.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# explicitly defines a network interface controller to
# attach to the APM CVM and allow communication with the internet 
resource "azurerm_network_interface" "apm" {
  name                      = "apm-nic-${random_string.random.result}"
  resource_group_name       = azurerm_resource_group.apm.name
  location                  = azurerm_resource_group.apm.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.apm.id
    public_ip_address_id          = azurerm_public_ip.apm.id
    private_ip_address_allocation = "Dynamic"
  }
}

# associates the APM network interface with its network security group
resource "azurerm_network_interface_security_group_association" "apm" {
  network_interface_id      = azurerm_network_interface.apm.id
  network_security_group_id = azurerm_network_security_group.apm.id
}
