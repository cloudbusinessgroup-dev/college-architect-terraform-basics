resource "azurerm_virtual_wan" "virtual_wan" {
  name                = (format("%s-%s-%s-VIRTUAL-WAN-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_virtual_hub" "virtual_hub" {
  name                = (format("%s-%s-%s-VIRTUAL-HUB-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_wan_id      = azurerm_virtual_wan.virtual_wan.id
  address_prefix      = var.address_prefix
  tags                = var.tags
}

resource "azurerm_vpn_gateway" "vpn_gateway" {
  name                = (format("%s-%s-%s-VPN-GATEWAY-001", var.coll_prefix, var.env_name, var.location_short))
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_hub_id      = azurerm_virtual_hub.virtual_hub.id
  tags                = var.tags
}