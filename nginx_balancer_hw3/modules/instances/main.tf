resource "yandex_compute_instance" "instances" {
  name          = var.vm_name
  hostname      = var.vm_name
  platform_id   = var.platform_id
  zone          = var.zone
  resources {
      cores         = var.cpu
      memory        = var.memory
      core_fraction = var.core_fraction
  } 

  boot_disk {
    initialize_params {
      image_id = var.image_id
      type     = var.disk_type
      size     = var.disk
    }
  }


  network_interface {
    subnet_id      = var.subnet_id
    nat            = var.nat
    ip_address     = var.internal_ip_address
    nat_ip_address = var.nat_ip_address
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}