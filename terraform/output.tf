output "vm_public_ip" {
  description = "The public IP address of the PHP VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_username" {
  description = "The admin username for SSH access"
  value       = azurerm_linux_virtual_machine.vm.admin_username
}

output "ssh_connection_command" {
  description = "Ready-to-use SSH command to connect to the VM"
  value       = "ssh -i ~/.ssh/id_rsa ${azurerm_linux_virtual_machine.vm.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "resource_group_name" {
  description = "The resource group containing all resources"
  value       = azurerm_resource_group.rg.name
}