#Credentials stuff 
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.0"
    }
  }
}

provider "azurerm" {
  features {
    
  }
}

#Get ip of the user 
data "http" "ip_public" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}
locals {
  public_ip =  jsondecode(data.http.ip_public.body)
}

#variables
variable "name_account" {
  type = string
}
variable "name_rg_account" {
  type = string
}
variable "region" {
  type = string
}
variable "range_vnet" {
  type = string
}
variable "range_management" {
  type = string
}
variable "range_service" {
  type = string
}

variable "name_RG" {
  type = string
}
variable "name_Vnet" {
  type = string
}

variable "source_uri_os_disk" {
  type = string
}

#Resource group 
resource "azurerm_resource_group" "this" {
  name = var.name_RG
  location = var.region
}

#VNet
resource "azurerm_virtual_network" "this" {
  name = var.name_Vnet
  address_space = [var.range_vnet]
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}
#Subnet Management
resource "azurerm_subnet" "management" {
  name = "Management_SubNet"
  address_prefixes = [var.range_management  ]
  resource_group_name = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}
#Subnet Service
resource "azurerm_subnet" "service" {
  name = "Service_Subnet"
  address_prefixes = [var.range_service]
  resource_group_name = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

#Security group
resource "azurerm_network_security_group" "management" {
  name = "Management_ssh_security"
  resource_group_name = azurerm_resource_group.this.name
  location = azurerm_resource_group.this.location
}

resource "azurerm_network_security_group" "service" {
  name = "service_securitygroup_security"
  resource_group_name = azurerm_resource_group.this.name
  location = azurerm_resource_group.this.location
}

resource "azurerm_network_security_rule" "ssh" {
  name = "SSH_Management"
  priority = 100
  resource_group_name = azurerm_resource_group.this.name
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  network_security_group_name = azurerm_network_security_group.management.name
  destination_port_range = "22"
  source_port_range = "*"
  source_address_prefix = "${local.public_ip.ip}/32"
  destination_address_prefix = "*"
  
}

resource "azurerm_network_security_rule" "home" {
  name = "Home_service"
  priority = 100
  resource_group_name = azurerm_resource_group.this.name
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  network_security_group_name = azurerm_network_security_group.service.name
  destination_port_range = "22"
  source_port_range = "*"
  source_address_prefix = "${local.public_ip.ip}/32"
  destination_address_prefix = "*"
}
resource "azurerm_network_security_rule" "office" {
  name = "Office_service"
  priority = 101
  resource_group_name = azurerm_resource_group.this.name 
  direction = "Inbound"
  access = "Allow"
  protocol = "*"
  network_security_group_name = azurerm_network_security_group.service.name
  destination_port_range = "22"
  source_port_range = "*"
  source_address_prefix = "104.129.196.40/32"
  destination_address_prefix = "*"
}
resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id = azurerm_network_interface.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}
resource "azurerm_network_interface_security_group_association" "service" {
  network_interface_id = azurerm_network_interface.service.id
  network_security_group_id = azurerm_network_security_group.service.id
}

#Two nics, and two IPS
resource "azurerm_public_ip" "management" {
  allocation_method = "Dynamic"
  name = "public_ip_management"
  resource_group_name = azurerm_resource_group.this.name
  location = azurerm_resource_group.this.location
}
resource "azurerm_public_ip" "service" {
  allocation_method = "Dynamic"
  name = "public_ip_service"
  resource_group_name = azurerm_resource_group.this.name
  location = azurerm_resource_group.this.location
  lifecycle {
    create_before_destroy = true
    }
}

resource "azurerm_network_interface" "service" {
  resource_group_name = azurerm_resource_group.this.name
  name = "service_ip"
  location = azurerm_resource_group.this.location

  ip_configuration {
    name = "service"
    subnet_id = azurerm_subnet.service.id
    private_ip_address_allocation =  "Dynamic"
    public_ip_address_id = azurerm_public_ip.service.id

  }
}

resource "azurerm_network_interface" "management" {
  resource_group_name = azurerm_resource_group.this.name
  name = "management_ip"
  location = azurerm_resource_group.this.location

  ip_configuration {
    name = "management"
    subnet_id = azurerm_subnet.management.id
    private_ip_address_allocation =  "Dynamic"
    public_ip_address_id = azurerm_public_ip.management.id
    primary = true
  }
}

#storage acct 
/*
resource "azurerm_storage_account" "this" {
  name = "nachoacc"
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  account_tier = "Standard"
  account_replication_type = "LRS"
  min_tls_version = "TLS1_2"
}

resource "azurerm_storage_container" "this" {
  name = "vhds"
  storage_account_name = azurerm_storage_account.this.name
}

#Copy the blob to the Container
resource "null_resource" "this" {
  provisioner "local-exec" {
    command = "az storage blob copy start --account-name ${azurerm_storage_account.this.name} --destination-container ${azurerm_storage_container.this.name} --destination-blob \"os_disk\" --source-uri ${var.source_uri_data}"
  }
}
*/

#import 
data "azurerm_storage_account" "this" {
  name = var.name_account 
  resource_group_name = var.name_rg_account
}

#managed disks
#Data disk 

#OS disk 

resource "azurerm_managed_disk" "os_disk" {
  name = "os_disk"
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  create_option = "Import"
  storage_account_type = "StandardSSD_LRS"
  storage_account_id = data.azurerm_storage_account.this.id
  source_uri = var.source_uri_os_disk
  os_type = "Linux"
}


#VM 
resource "azurerm_virtual_machine" "this" {
  name = "vzenlab03"
  
  resource_group_name = azurerm_resource_group.this.name
  location = azurerm_resource_group.this.location
  vm_size = "Standard_D8_v3" 
  network_interface_ids = [
    azurerm_network_interface.management.id,
    azurerm_network_interface.service.id,                                           
  ]
  primary_network_interface_id = azurerm_network_interface.management.id
  os_profile_linux_config {  
    disable_password_authentication = false
  }
  storage_os_disk {
    create_option = "Attach"
    managed_disk_id = azurerm_managed_disk.os_disk.id
    name = azurerm_managed_disk.os_disk.name
    disk_size_gb = azurerm_managed_disk.os_disk.disk_size_gb
    os_type = "Linux"
  }
}
