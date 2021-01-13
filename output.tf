output "cassandra_vm" {
  value       = local.vms
  sensitive   = false
  description = "cassandra nodes"
}
