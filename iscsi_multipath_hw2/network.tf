resource "yandex_vpc_network" "ru-central1-a-servers-network-01" {
  name = "pcs-servers-network-01"
}

resource "yandex_vpc_subnet" "pcs-servers-subnet-01" {
  name           = "pcs-servers-subnet-01"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.ru-central1-a-servers-network-01.id
  v4_cidr_blocks = ["10.160.0.0/24"]
}

resource "yandex_vpc_subnet" "pcs-servers-subnet-02" {
  name           = "pcs-servers-subnet-02"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.ru-central1-a-servers-network-01.id
  v4_cidr_blocks = ["10.180.3.0/24"]
}

resource "yandex_vpc_subnet" "iscsi-servers-subnet-01" {
  name           = "iscsi-servers-subnet-01"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.ru-central1-a-servers-network-01.id
  v4_cidr_blocks = ["10.180.0.0/24"]
}

resource "yandex_vpc_subnet" "iscsi-servers-subnet-02" {
  name           = "iscsi-servers-subnet-02"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.ru-central1-a-servers-network-01.id
  v4_cidr_blocks = ["10.180.1.0/24"]
}

resource "yandex_vpc_subnet" "iscsi-servers-subnet-03" {
  name           = "iscsi-servers-subnet-03"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.ru-central1-a-servers-network-01.id
  v4_cidr_blocks = ["10.180.2.0/24"]
}
