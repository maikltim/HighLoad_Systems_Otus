output "external_ip_address_msk-ngx-servers" {
  value = yandex_compute_instance.wp-app.network_interface[0].nat_ip_address
}