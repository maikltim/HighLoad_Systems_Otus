resource "yandex_vpc_network" "this" {
  name = "vpc-network"
}

resource "yandex_vpc_subnet" "this" {
  name = "vpc-subnet"
  v4_cidr_blocks = ["10.10.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.this.id
}