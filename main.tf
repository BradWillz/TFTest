data "azurerm_client_config" "current" {}

# Create our Resource Group - rg-bkw-prod-01
resource "azurerm_resource_group" "rg" {
  name     = "rg-bkw-prod-01"
  location = "UK South"
}

# Create our Virtual Network - vn-bkw-prod-01
resource "azurerm_virtual_network" "vnet" {
  name                = "vn-bkw-prod-01"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create our Subnet to hold our VM - Virtual Machines
resource "azurerm_subnet" "sn" {
  name                 = "VM"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create our Azure Storage Account - bradkwillssa08
resource "azurerm_storage_account" "bradkwillssa08" {
  name                     = "bradkwillssa08"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    environment = "jonnychipzrox"
  }
}

# Create our Network Interface - nic-bkw-prod01
resource "azurerm_network_interface" "nic" {
  name                = "nic-bkw-prod01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sn.id
    private_ip_address_allocation = "Dynamic"
  }
}

#  Create a Key Vault - kv-bkw-prod-01
resource "azurerm_key_vault" "kv" {
  name                        = "kv-bkw-prod-01"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"

  purge_protection_enabled    = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Backup",
      "Restore",
      "Recover",
      "Purge"
    ]
  }
}

# Generate a random password
resource "random_password" "password" {
  length  = 16
  special = true
}

# Store the password in Key Vault
resource "azurerm_key_vault_secret" "vm_password" {
  name         = "vm-password"
  value        = random_password.password.result
  key_vault_id = azurerm_key_vault.kv.id
}

# Create our Virtual Machine - vm-bkw-prod-01
resource "azurerm_virtual_machine" "vm" {
  name                  = "vm-bkw-prod-01"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "adminuser"
    admin_password = azurerm_key_vault_secret.vm_password.value
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}