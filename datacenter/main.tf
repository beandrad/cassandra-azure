locals {
  name_prefix = "${var.cluster_prefix}-${var.dc_prefix}"
}

resource "azurerm_resource_group" "dc" {
  name     = "${local.name_prefix}-rg"
  location = var.location
}

resource "azurerm_network_security_group" "dc" {
  name                = "${local.name_prefix}-nsg"
  location            = azurerm_resource_group.dc.location
  resource_group_name = azurerm_resource_group.dc.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "cass-internal"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "cass-client"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9042"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


  security_rule {
    name                       = "cass-jmx"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7199"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "cass-prometheus"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7070"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "dc" {
  name                = "${local.name_prefix}-vn"
  location            = azurerm_resource_group.dc.location
  resource_group_name = azurerm_resource_group.dc.name
  address_space       = [var.address_space]

  tags = {
    environment = var.environment
  }
}

resource "azurerm_subnet" "dc" {
  name                 = "${local.name_prefix}-sn"
  resource_group_name  = azurerm_resource_group.dc.name
  virtual_network_name = azurerm_virtual_network.dc.name
  address_prefixes     = [var.subnet_prefix]
}

resource "azurerm_public_ip" "dc" {
  count                   = var.vm_count
  name                    = "${local.name_prefix}-pip-${count.index}"
  location                = azurerm_resource_group.dc.location
  resource_group_name     = azurerm_resource_group.dc.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}

resource "azurerm_network_interface" "dc" {
  count               = var.vm_count
  name                = "${local.name_prefix}-nic-${count.index}"
  location            = azurerm_resource_group.dc.location
  resource_group_name = azurerm_resource_group.dc.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dc.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.dc.*.id, count.index)
  }
}

resource "azurerm_network_interface_security_group_association" "dc" {
  count                     = var.vm_count
  network_interface_id      = element(azurerm_network_interface.dc.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.dc.id
}

resource "azurerm_linux_virtual_machine" "dc" {
  count                           = var.vm_count
  name                            = "${local.name_prefix}-vm-${count.index}"
  location                        = azurerm_resource_group.dc.location
  resource_group_name             = azurerm_resource_group.dc.name
  size                            = var.vm_sku
  disable_password_authentication = "false"
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  network_interface_ids = [
    element(azurerm_network_interface.dc.*.id, count.index),
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-cassandra.sh"
    destination = "/tmp/setup-cassandra.sh"

    connection {
      type     = "ssh"
      host     = self.public_ip_address
      user     = var.vm_admin_username
      password = var.vm_admin_password
    }
  }

  tags = {
    environment = var.environment
  }
}

resource "azurerm_virtual_machine_extension" "dc" {
  count                = var.vm_count
  name                 = "${local.name_prefix}-install-mve-${count.index}"
  virtual_machine_id   = element(azurerm_linux_virtual_machine.dc.*.id, count.index)
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${filebase64("${path.module}/scripts/install-cassandra.sh")}"
    }
SETTINGS
}
