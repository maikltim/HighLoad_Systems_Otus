locals {
  
}


resource "yandex_compute_instance" "spb-pcs-servers" {

  name                      = "spb-pcs-${count.index + 1}"
  count                     = var.data["count"]
  platform_id               = "standard-v1"
  hostname                  = "spb-pcs-${count.index + 1}"
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8p7vi5c5bbs2s5i67s" //Centos 7
      size     = 10
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.pcs-servers-subnet-01.id
    nat       = true
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.iscsi-servers-subnet-02.id
    nat        = false
    ip_address = "10.180.1.20${count.index + 1}"
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.iscsi-servers-subnet-03.id
    nat        = false
    ip_address = "10.180.2.20${count.index + 1}"
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.pcs-servers-subnet-02.id
    nat        = false
    ip_address = "10.180.3.20${count.index + 1}"
  }

  metadata = {
    user-data = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  depends_on = [
    yandex_compute_instance.spb-iscsi-servers
  ]
}

resource "yandex_compute_instance" "spb-iscsi-servers" {

  name                      = "spb-iscsi-1"
  count                     = 1
  platform_id               = "standard-v1"
  hostname                  = "spb-iscsi-1"
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8p7vi5c5bbs2s5i67s" //Centos 7
      size     = 10
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.iscsi-servers-subnet-01.id
    nat       = true
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.iscsi-servers-subnet-02.id
    nat        = false
    ip_address = "10.180.1.204"
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.iscsi-servers-subnet-03.id
    nat        = false
    ip_address = "10.180.2.204"
  }

  secondary_disk {
    disk_id = yandex_compute_disk.spb-iscsi-servers-iscsi-secondary-data-disk.id
  }

  metadata = {
    user-data = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_disk" "spb-iscsi-secondary-data-disk" {

  name = "spb-iscsi-secondary-data-disk-01"
  type = "network-hdd"
  zone = "ru-central1-a"
  size = "1"
}