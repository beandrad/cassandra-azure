variable "subnet_prefix" {
}

variable "address_space" {
}

variable "location" {
  description = "Datacenter cluster region"
}

variable "cluster_prefix" {
  description = "prefix for resource names in Cassandra cluster"
}

variable "dc_prefix" {
  description = "prefix for resource names in DC"
}

variable "vm_admin_username" {
  description = "login username for admin user"
}

variable "vm_admin_password" {
  description = "password for admin user"
}

variable "vm_sku" {
  description = "size of vms to be provisioned"
  default     = "Standard_D2_v3"
}

variable "environment" {
  description = "environment tag"
  default     = "dev"
}

variable "vm_count" {
  description = "Number of VMs in datacenter"
  default     = 2
}
