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



module "keyvault" {

  depends_on = [
    azurerm_resource_group.rg_infra
  ]

  name                   = lower((format("%s-%s-%s-KV", var.coll_prefix, var.env_name, var.location_short)))
  source                 = "./modules/keyvault"
  resource_group_name    = azurerm_resource_group.rg_infra.name
  location               = var.location
  tenant_id              = var.tenant_id
  tags                   = var.tags
  object_id              = var.object_id
  coll_prefix            = var.coll_prefix
  env_name               = var.env_name
  location_short         = var.location_short
}

resource "random_password" "sql-server-admin-password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "hub-server-password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "infra-server-password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

data "azurerm_key_vault_secret" "sql-server-admin-password-secret-data" {
  count        = var.initial_deployment_keyvault ? 0 : 1
  name         = lower((format("%s-%s-%s-SQL-Server-Instance-Password", var.coll_prefix, var.env_name, var.location_short)))
  key_vault_id = module.keyvault.kv_id
}

data "azurerm_key_vault_secret" "hub-server-password-secret-data" {
  count        = var.initial_deployment_keyvault ? 0 : 1
  name         = lower((format("%s-%s-%s-Hub-Server-Password", var.coll_prefix, var.env_name, var.location_short)))
  key_vault_id = module.keyvault.kv_id
}

data "azurerm_key_vault_secret" "infra-server-password-secret-data" {
  count        = var.initial_deployment_keyvault ? 0 : 1
  name         = lower((format("%s-%s-%s-Infra-Server-Password", var.coll_prefix, var.env_name, var.location_short)))
  key_vault_id = module.keyvault.kv_id
}

resource "azurerm_key_vault_secret" "sql-server-admin-password-secret" {
  name         = lower((format("%s-%s-%s-SQL-Server-Instance-Password", var.coll_prefix, var.env_name, var.location_short)))
  value        = (data.azurerm_key_vault_secret.sql-server-admin-password-secret-data != [] ? data.azurerm_key_vault_secret.sql-server-admin-password-secret-data[0].value : random_password.sql-server-admin-password.result)
  key_vault_id = module.keyvault.kv_id
}

resource "azurerm_key_vault_secret" "hub-server-password-secret" {
  name         = lower((format("%s-%s-%s-Hub-Server-Password", var.coll_prefix, var.env_name, var.location_short)))
  value        = (data.azurerm_key_vault_secret.hub-server-password-secret-data != [] ? data.azurerm_key_vault_secret.hub-server-password-secret-data[0].value : random_password.hub-server-password.result)
  key_vault_id = module.keyvault.kv_id
}

resource "azurerm_key_vault_secret" "infra-server-password-secret" {
  name         = lower((format("%s-%s-%s-Infra-Server-Password", var.coll_prefix, var.env_name, var.location_short)))
  value        = (data.azurerm_key_vault_secret.infra-server-password-secret-data != [] ? data.azurerm_key_vault_secret.infra-server-password-secret-data[0].value : random_password.infra-server-password.result)
  key_vault_id = module.keyvault.kv_id
}

resource "azurerm_network_security_group" "nsg_vnet_hub" {
  name  = (format("%s-%s-%s-NSG-HUB-001", var.coll_prefix, var.env_name, var.location_short))
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
  admin_password = azurerm_key_vault_secret.hub-server-password-secret.value
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
  name = (format("%s-%s-%s-001", var.coll_prefix, var.env_name, var.location_short))
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
  address_prefixes = ["10.1.1.0/27"]
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
  name = (format("%s-%s-%s-NIC-DC-001", var.coll_prefix, var.env_name, var.location_short))
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
  size = "Standard_DS1_v2"
  admin_username = "admindc"
  admin_password = azurerm_key_vault_secret.infra-server-password-secret.value
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



resource "azurerm_network_interface" "nic_virtual_appliance_001" {
  name = (format("%s-%s-%s-NIC-VA-001", var.coll_prefix, var.env_name, var.location_short))
  resource_group_name = azurerm_resource_group.coll_part.name
  location = var.location
  tags = var.tags

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.vnet_hub_subnet_default.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "tls_private_key" "virtualappliance-private_key-01" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "linux_va_pem" { 
  filename = "${path.module}/linuxvirtualappliance_pk.pem"
  content = tls_private_key.virtualappliance-private_key-01.private_key_pem
}

resource "azurerm_linux_virtual_machine" "virtualappliance-vm-01" {
  name                  = (format("%s-%s-%s-VM-VIRTAPPL-001", var.coll_prefix, var.env_name, var.location_short))
  location              = var.location
  tags                  = var.tags
  resource_group_name   = azurerm_resource_group.coll_part.name
  network_interface_ids = [azurerm_network_interface.nic_virtual_appliance_001.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = (format("%s-%s-%s-DISK-VIRTAPPL-001", var.coll_prefix, var.env_name, var.location_short))
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "VMVIRTAPP001"
  admin_username                  = "linuxvaadmin"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "linuxvaadmin"
    public_key = tls_private_key.virtualappliance-private_key-01.public_key_openssh
  }
}

resource "azurerm_route_table" "route_table_virtual_appliance" {
  name                          = (format("%s-%s-%s-RT-VIRTAPPL-001", var.coll_prefix, var.env_name, var.location_short))
  location                      = var.location
  tags                          = var.tags
  resource_group_name           = azurerm_resource_group.rg_infra.name
  disable_bgp_route_propagation = false

  route {
    name           = (format("%s-%s-ROUTE-HUB-NETWORK-001", var.coll_prefix, var.env_name))
    address_prefix = "10.1.0.4/32"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.0.5"
  }

  route {
    name           = (format("%s-%s-ROUTE-CORP-NETWORK-001", var.coll_prefix, var.env_name))
    address_prefix = "10.32.0.0/12"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.0.5"
  }
}


resource "azurerm_subnet_route_table_association" "default_subnet_spoke_route_table" {
  subnet_id      = azurerm_subnet.default_subnet_spoke_infra.id
  route_table_id = azurerm_route_table.route_table_virtual_appliance.id
}

resource "azurerm_subnet" "backend_subnet_spoke_infra" {
  name = "Backend"
  resource_group_name = azurerm_resource_group.rg_infra.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke_infra.name
  address_prefixes = ["10.1.1.32/27"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_subnet_network_security_group_association" "nsg_to_backend_subnet_spoke_infra" {
  subnet_id = azurerm_subnet.backend_subnet_spoke_infra.id
  network_security_group_id = azurerm_network_security_group.nsg_vnet_spoke_infra.id
}

resource "azurerm_private_dns_zone" "backend_private_dns" {
  name = var.backend_private_dns
  resource_group_name = azurerm_resource_group.rg_infra.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "private-dns-link" {
  name = format("%s-%s-%s-PRIVATE-DNS-ZONE-VNET-LINK-SPOKE-001", var.coll_prefix, var.env_name, var.location_short)
  resource_group_name = azurerm_resource_group.rg_infra.name
  private_dns_zone_name = azurerm_private_dns_zone.backend_private_dns.name
  virtual_network_id = azurerm_virtual_network.vnet_spoke_infra.id
}

resource "azurerm_private_dns_zone" "endpoint-dns-private-zone" {
  name = "${var.backend_dns_privatelink}.database.windows.net"
  resource_group_name = azurerm_resource_group.rg_infra.name
}

resource "azurerm_mssql_server" "sql-server" {
  name = "college-sql-server-instance" #NOTE: globally unique
  resource_group_name = azurerm_resource_group.rg_infra.name
  location = var.location
  version = "12.0"
  administrator_login = "collegesqladmin"
  administrator_login_password = azurerm_key_vault_secret.sql-server-admin-password-secret.value
  public_network_access_enabled = false
}

resource "azurerm_sql_database" "sql-db" {
  depends_on = [azurerm_mssql_server.sql-server]
  name = "college-db"
  resource_group_name = azurerm_resource_group.rg_infra.name
  location = var.location
  server_name = azurerm_mssql_server.sql-server.name
  edition = "Standard"
  collation = "Latin1_General_CI_AS"
  max_size_bytes = "10737418240"
  zone_redundant = false
  read_scale = false
}

resource "azurerm_private_endpoint" "db-endpoint" {
  depends_on = [azurerm_mssql_server.sql-server]
  name = (format("%s-%s-%s-SQL-DB-ENDPOINT-001", var.coll_prefix, var.env_name, var.location_short))
  location = var.location
  resource_group_name = azurerm_resource_group.rg_infra.name
  subnet_id = azurerm_subnet.backend_subnet_spoke_infra.id
  private_service_connection {
    name = "sql-db-endpoint"
    is_manual_connection = "false"
    private_connection_resource_id = azurerm_mssql_server.sql-server.id
    subresource_names = ["sqlServer"]
  }
}

data "azurerm_private_endpoint_connection" "endpoint-connection" {
  depends_on = [azurerm_private_endpoint.db-endpoint]
  name = azurerm_private_endpoint.db-endpoint.name
  resource_group_name = azurerm_resource_group.rg_infra.name
}

resource "azurerm_private_dns_a_record" "endpoint-dns-a-record" {
  depends_on = [azurerm_mssql_server.sql-server]
  name = lower(azurerm_mssql_server.sql-server.name)
  zone_name = azurerm_private_dns_zone.endpoint-dns-private-zone.name
  resource_group_name = azurerm_resource_group.rg_infra.name
  ttl = 300
  records = [data.azurerm_private_endpoint_connection.endpoint-connection.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-zone-to-vnet-link" {
  name = "sql-db-vnet-link"
  resource_group_name = azurerm_resource_group.rg_infra.name
  private_dns_zone_name = azurerm_private_dns_zone.endpoint-dns-private-zone.name
  virtual_network_id = azurerm_virtual_network.vnet_spoke_infra.id
}
