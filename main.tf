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