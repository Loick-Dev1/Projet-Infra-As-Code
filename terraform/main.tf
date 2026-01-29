#############################
# main.tf - corrected
#############################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
}

#############################
# Variables
#############################
variable "location" {
  description = "Azure location to deploy resources in. Change once and keep consistent."
  type        = string
  default     = "francecentral"   # change to "francecentral" if you are sure it's available
}

variable "vm_size" {
  description = "VM size. Change this if SKU not available in region."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "ssh_public_key_path" {
  description = "Path to your public SSH key file. Use an absolute path if ~ doesn't expand on your OS."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "rg-tp-terraform"
}

variable "tags" {
  description = "Tags applied to resources"
  type        = map(string)
  default     = {
    environment = "TP-Terraform"
  }
}

#############################
# Resource Group
#############################
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

#############################
# Virtual Network & Subnet
#############################
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-tp"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#############################
# Public IP
#############################
resource "azurerm_public_ip" "public_ip" {
  name                = "public-ip-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"  # Standard SKU requires Static allocation
  sku               = "Standard"
  tags              = var.tags
}

#############################
# Network Security Group
#############################
resource "azurerm_network_security_group" "web_nsg" {
  name                = "nsg-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#############################
# Network Interface
#############################
resource "azurerm_network_interface" "nic" {
  name                = "nic-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

#############################
# Linux VM
#############################
resource "azurerm_linux_virtual_machine" "mon_serveur_web" {
  name                = "serveur-web-tp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Optional: base64-encoded custom data script (create script.sh in module dir)
  # If you don't want a custom script, comment/remove this line
  custom_data = filebase64("${path.module}/script.sh")

  tags = var.tags
}

#############################
# Outputs
#############################
output "adresse_ip_publique" {
  value       = azurerm_public_ip.public_ip.ip_address
  description = "The public IP address of the web server"
}

output "vm_private_ip" {
  value       = azurerm_network_interface.nic.private_ip_address
  description = "Private IP assigned to the NIC"
}
