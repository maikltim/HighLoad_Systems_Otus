output "public_ip" {
  description = "Public IP address for instance"
  value = yandex_compute_instance.this.network_interface.0.nat_ip_address
}