variable "cluster_prefix" {
  type = string
}

variable "dcs" {
  type = list(object({
    name          = string
    location      = string
    vm_count      = number
    address_space = string
    subnet_prefix = string
  }))
}

variable "vm_admin_username" {
  description = "login username for vm admin user"
}

variable "vm_admin_password" {
  description = "password for vm admin user"
}
