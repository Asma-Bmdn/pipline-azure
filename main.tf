provider "azurerm" {
  features {}
}

# Déclarer la ressource azurerm_resource_group
resource "azurerm_resource_group" "RG" {
  name     = "resource-group-terra"
  location = "francecentral"
}

# Déclarer la ressource azurerm_network_security_group
resource "azurerm_network_security_group" "nsg" {
  name                = "NSG-SSH"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  # Autres attributs de la ressource...
}


# Créer une base de données Azure SQL
resource "azurerm_sql_server" "sql_server" {
  name                         = "asma123425-sql-server"
  resource_group_name          = azurerm_resource_group.RG.name
  location                     = azurerm_resource_group.RG.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd"  # Remplacez par votre mot de passe sécurisé
}

resource "azurerm_sql_database" "sql_db" {
  name                        = "my-sql-database123425"
  resource_group_name         = azurerm_resource_group.RG.name
  location                    = azurerm_resource_group.RG.location
  server_name                 = azurerm_sql_server.sql_server.name
  edition                     = "Standard"
}


# Créer un réseau virtuel et un sous-réseau
resource "azurerm_virtual_network" "AZVN" {
  name                = "AZVN-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_subnet" "Azure_subnet" {
  name                 = "Azure_subnet"
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.AZVN.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Créer une adresse IP publique
resource "azurerm_public_ip" "public_ip" {
  name                = "public-ip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method   = "Dynamic"
}

# Créer une interface réseau
resource "azurerm_network_interface" "Azure_NI" {
  name                = "Azure_NI"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Azure_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Associer le NSG à l'interface réseau de la machine virtuelle
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.Azure_NI.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
# Générer une nouvelle paire de clés SSH
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
# Créer une règle entrante pour permettre SSH
resource "azurerm_network_security_rule" "ssh_rule" {
  name                        = "Allow-SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.RG.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}


# Créer une machine virtuelle Linux
resource "azurerm_linux_virtual_machine" "master" {
  name                = "master"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = "Standard_F2"
  admin_username      = "Admin_azure"
  network_interface_ids = [azurerm_network_interface.Azure_NI.id]

  admin_ssh_key {
    username   = "Admin_azure"
    public_key = tls_private_key.example.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# Stocker la clé privée générée
output "private_key" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

