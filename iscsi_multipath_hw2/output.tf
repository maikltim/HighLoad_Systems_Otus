output "external_ip_address_msk-pcs-servers" {
  value = [yandex_compute_instance.msk-pcs-servers[*].hostname, yandex_compute_instance.msk-pcs-servers[*].network_interface.0.nat_ip_address]
}

output "internal_ip_address_msk-pcs-servers" {
  value = [yandex_compute_instance.msk-pcs-servers[*].hostname, yandex_compute_instance.msk-pcs-servers[*].network_interface.0.ip_address]
}

output "external_ip_address_msk-iscsi-servers" {
  value = [yandex_compute_instance.msk-iscsi-servers[*].hostname, yandex_compute_instance.msk-iscsi-servers[*].network_interface.0.nat_ip_address]
}

output "internal_ip_address_msk-iscsi-servers" {
  value = [yandex_compute_instance.msk-iscsi-servers[*].hostname, yandex_compute_instance.msk-iscsi-servers[*].network_interface.0.ip_address]
}