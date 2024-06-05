output "external_ip_address_spb-pcs-servers" {
  value = [yandex_compute_instance.spb-pcs-servers[*].hostname, yandex_compute_instance.spb-pcs-servers[*].network_interface.0.nat_ip_address]
}

output "internal_ip_address_spb-pcs-servers" {
  value = [yandex_compute_instance.spb-pcs-servers[*].hostname, yandex_compute_instance.spb-pcs-servers[*].network_interface.0.ip_address]
}

output "external_ip_address_spb-iscsi-servers" {
  value = [yandex_compute_instance.spb-iscsi-servers[*].hostname, yandex_compute_instance.spb-iscsi-servers[*].network_interface.0.nat_ip_address]
}

output "internal_ip_address_spb-iscsi-servers" {
  value = [yandex_compute_instance.spb-iscsi-servers[*].hostname, yandex_compute_instance.spb-iscsi-servers[*].network_interface.0.ip_address]
}