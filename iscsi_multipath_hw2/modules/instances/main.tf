terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}


resource "yandex_compute_instance" "instances" {
  name = var.vm_name 
  hostname = var.vm_name
  platform_id = var.platform_id
  zone = var.zone
  resources {
    cores = var.cpu
    memory = var.memory
    core_fraction = var.core_fraction
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
      size = var.disk
      type = var.disk_type
    }
  }

  dynamic "secondary_disk" {
    for_each = var.secondary_disk
    content {
      disk_id = lookup(secondary_disk.value, "disk_id")
      auto_delete = lookup(secondary_disk.value, "auto_delete", true)
      mode = lookup(secondary_disk.value, "mode", "READ_WRITE")
    }
  }


  network_interface {
    subnet_id = var.subnet_id
    nat = var.nat
    ip_address = var.internal_ip_address
    nat_ip_address = var.nat_ip_address
  }


  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  allow_stopping_for_update = var.allow_stopping_for_update
}