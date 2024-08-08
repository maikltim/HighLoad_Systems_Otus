output "masters-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.masters :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "dbs-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.dbs :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "bes-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.bes :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "lbs-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.lbs :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}