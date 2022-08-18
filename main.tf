terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
  
  backend "azurerm" {
    resource_group_name   = "Terraform"
    storage_account_name  = "collegeinfrastructure"
    container_name        = "tf-state"
    key                   = "terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id

  features {}
}

resource "azurerm_resource_group" "coll_part" {
  name     = (format("%s-%s-%s-SHARED", var.coll_prefix, var.env_name, var.location_short))
  location = var.location
  tags     = var.tags
}

resource "azurerm_network_security_group" "nsg_vnet_hub" {
  name  = (format("%s-%s-%s-NSG-HUB-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = azurerm_resource_group.coll_part.name
  location = var.location
  tags = var.tags
}

resource "azurerm_network_ddos_protection_plan" "prot_plan_hub" {
 name = (format("%s-%s-%s-DDOSPP-HUB-001", var.coll_prefix, var.env_name, var.location_short))
 resource_group_name = azurerm_resource_group.coll_part.name
 location = var.location
 tags = var.tags
}

resource "azurerm_virtual_network" "vnet_hub" {
 name =  (format("%s-%s-%s-VNET-HUB-001", var.coll_prefix, var.env_name, var.location_short))
 resource_group_name = azurerm_resource_group.coll_part.name
 address_space = ["10.1.0.0/24"]
 location = var.location
 tags = var.tags

 ddos_protection_plan {
   id = azurerm_network_ddos_protection_plan.prot_plan_hub.id
   enable = true
 }
}

resource "azurerm_subnet" "vnet_hub_subnet_default" {
  name = "Default"
  resource_group_name = azurerm_resource_group.coll_part.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes = ["10.1.0.0/28"]
}

resource "azurerm_subnet" "vnet_hub_subnet_shared_bastionhost" {
 name = "AzureBastionSubnet"
 resource_group_name = azurerm_resource_group.coll_part.name
 virtual_network_name = azurerm_virtual_network.vnet_hub.name
 address_prefixes = ["10.1.0.32/27"] 
}

resource "azurerm_subnet_network_security_group_association" "nsg_to_default_subnet" {
  subnet_id = azurerm_subnet.vnet_hub_subnet_default.id
  network_security_group_id = azurerm_network_security_group.nsg_vnet_hub.id  
}

resource "azurerm_public_ip" "bastion_pip" {
  name = (format("%s-%s-%s-PIP-BASTION-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = azurerm_resource_group.coll_part.name
  location = var.location
  tags = var.tags
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_bastion_host" "bastionhost" {
  name = (format("%s-%s-%s-BASTIONHOST-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = azurerm_resource_group.coll_part.name
  location = var.location
  tags = var.tags

  ip_configuration {
    name = "configuration"
    subnet_id = azurerm_subnet.vnet_hub_subnet_shared_bastionhost.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}

resource "azurerm_network_interface" "nic_bastion_host" {
  name = (format("%s-%s-%s-NIC-JH-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = azurerm_resource_group.coll_part.name
  location = var.location
  tags = var.tags

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.vnet_hub_subnet_default.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "jumphost" {
  name = (format("%s-%s-%s-VM-JH-001", var.coll_prefix, var.env_name, var.location_short))
  computer_name = "VMBASTJH"
  resource_group_name = azurerm_resource_group.coll_part.name
  location = var.location
  tags = var.tags
  size = "Standard_B1s"
  admin_username = "adminjh"
  admin_password = "Passw0rd001"
  network_interface_ids = [
    azurerm_network_interface.nic_bastion_host.id
  ]

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2019-Datacenter"
    version = "latest"
  }
}

resource "azurerm_resource_group" "rg_infra" {
  name = (format("%s-%s-%s-INFRA-001", var.coll_prefix, var.env_name, var.location_short))
  location = var.location
  tags = var.tags
}

resource "azurerm_network_security_group" "nsg_vnet_spoke_infra" {
  name = (format("%s-%s-%s-NSG-SPOKE-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = azurerm_resource_group.rg_infra.name
  location = var.location
  tags = var.tags
}

resource "azurerm_virtual_network" "vnet_spoke_infra" {
  name = (format("%s-%s-%s-VNET-SPOKE-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = azurerm_resource_group.rg_infra.name
  address_space = ["10.1.1.0/24"]
  location = var.location
  tags = var.tags
}

resource "azurerm_subnet" "default_subnet_spoke_infra" {
  name = "Default"
  resource_group_name = azurerm_resource_group.rg_infra.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke_infra.name
  address_prefixes = ["10.1.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "nsg_to_default_subnet_spoke_infra" {
  subnet_id = azurerm_subnet.default_subnet_spoke_infra.id
  network_security_group_id = azurerm_network_security_group.nsg_vnet_spoke_infra.id
}

resource "azurerm_virtual_network_peering" "peering-infra-spoke-to-hub" {
  name = "Peering_SPOKE-001_to_HUB-001"
  resource_group_name = azurerm_resource_group.coll_part.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_spoke_infra.id
  allow_forwarded_traffic = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "peering-hub-to-infra-spoke" {
  name = "Peering_HUB-001_to_SPOKE-001"
  resource_group_name = azurerm_resource_group.rg_infra.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke_infra.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_hub.id
  allow_forwarded_traffic = true
  allow_virtual_network_access = true
}

resource "azurerm_network_interface" "nic_infra_dc_server" {
  name = (format("%s-%s-%s-NIC-INFRA-DC-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = azurerm_resource_group.rg_infra.name
  location = var.location
  tags = var.tags

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.default_subnet_spoke_infra.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "infra_dc_server" {
  name = (format("%s-%s-%s-VM-DC-001", var.coll_prefix, var.env_name, var.location_short))
  computer_name = "VMDC"
  resource_group_name = azurerm_resource_group.rg_infra.name
  location = var.location
  tags = var.tags
  size = "Standard_B1s"
  admin_username = "admindc"
  admin_password = "Passw0rd001"
  network_interface_ids = [
    azurerm_network_interface.nic_infra_dc_server.id
  ]

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2019-Datacenter"
    version = "latest"
  }
}