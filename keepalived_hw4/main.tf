locals {
  vm_user            = "cloud-user"
  ssh_private_key = "~/.ssh/id_rsa"
  ssh_public_key = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  cloud_id  = var.yc_cloud
  zone = "ru-central1-b"
  vpc_name = "my_vpc_network"
  
  folders = {
    "loadbalancer-folder" = {}
  }

  subnets = {
    "loadbalancer-subnet" = {
        v4_cidr_blocks = ["10.10.10.0/24"]
    }
  }

  nginx_count = "2"
  backend_count = "2"
  iscsi_count   = "1"
  db_count      = "1"

}

resource "yandex_resourcemanager_folder" "folders" {
  for_each = local.folders
  name     = each.key
  cloud_id = local.cloud_id
}


resource "yandex_vpc_network" "vpc" {
  folder_id = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  name      = local.vpc_name
}


resource "yandex_vpc_subnet" "subnets" {
  for_each = local.subnets
  name           = each.key
  v4_cidr_blocks = each.value["v4_cidr_blocks"]
  zone           = local.zone
  folder_id      = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  network_id     = yandex_vpc_network.vpc.id
}

module "nginx-servers" {
  source         = "./modules/instances"
  count          = local.nginx_count
  vm_name        = "nginx-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat       = true
    }
    if subnet.name == "loadbalancer-subnet" #or subnet.name == "nginx-subnet"
  }
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "nginx-servers" {
  count      = length(module.nginx-servers)
  name       = module.nginx-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  depends_on = [module.nginx-servers]
}

module "backend-servers" {
  source         = "./modules/instances"
  count          = local.backend_count
  vm_name        = "backend-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat       = true
    }
    if subnet.name == "loadbalancer-subnet" #or subnet.name == "backend-subnet"
  }
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "backend-servers" {
  count      = length(module.backend-servers)
  name       = module.backend-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  depends_on = [module.backend-servers]
}

module "iscsi-servers" {
  source         = "./modules/instances"
  count          = local.iscsi_count
  vm_name        = "iscsi-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat       = true
    }
    if subnet.name == "loadbalancer-subnet" #or subnet.name == "backend-subnet"
  }
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {
    for disk in yandex_compute_disk.disks :
    disk.name => {
      disk_id = disk.id
    }
    if disk.name == "web-${format("%02d", count.index + 1)}"
  }
  depends_on = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "iscsi-servers" {
  count      = length(module.iscsi-servers)
  name       = module.iscsi-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  depends_on = [module.iscsi-servers]
}

module "db-servers" {
  source         = "./modules/instances"
  count          = local.db_count
  vm_name        = "db-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat       = true
    }
    if subnet.name == "loadbalancer-subnet"
  }
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "db-servers" {
  count      = length(module.db-servers)
  name       = module.db-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  depends_on = [module.db-servers]
}

resource "local_file" "inventory_file" {
  content = templatefile("${path.module}/templates/inventory.tpl",
    {
      nginx-servers = data.yandex_compute_instance.nginx-servers
      backend-servers = data.yandex_compute_instance.backend-servers
      iscsi-servers   = data.yandex_compute_instance.iscsi-servers
      db-servers      = data.yandex_compute_instance.db-servers
    }
  )
  filename = "${path.module}/inventory.ini"
}

resource "local_file" "group_vars_all_file" {
  content = templatefile("${path.module}/templates/group_vars_all.tpl",
    {
      nginx-servers = data.yandex_compute_instance.nginx-servers
      backend-servers = data.yandex_compute_instance.backend-servers
      iscsi-servers   = data.yandex_compute_instance.iscsi-servers
      db-servers      = data.yandex_compute_instance.db-servers
      subnet_cidrs    = yandex_vpc_subnet.subnets["loadbalancer-subnet"].v4_cidr_blocks
    }
  )
  filename = "${path.module}/group_vars/all/main.yml"
}


resource "yandex_compute_disk" "disks" {
  count     = local.iscsi_count
  name      = "web-${format("%02d", count.index + 1)}"
  folder_id = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  size      = "1"
  zone      = local.zone
}


resource "yandex_lb_target_group" "keepalived_group" {
  name      = "my-keepalived-group"
  region_id = "ru-central1"
  folder_id = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id

  dynamic "target" {
    for_each = data.yandex_compute_instance.nginx-servers[*].network_interface.0.ip_address
    content {
      subnet_id = yandex_vpc_subnet.subnets["loadbalancer-subnet"].id
      address   = target.value
    }
  }
}

resource "yandex_lb_network_load_balancer" "keepalived" {
  name = "my-network-load-balancer"
  folder_id = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id

  listener {
    name = "my-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.keepalived_group.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/ping"
      }
    }
  }
}

data "yandex_lb_network_load_balancer" "keepalived" {
  name = "my-network-load-balancer"
  folder_id = yandex_resourcemanager_folder.folders["loadbalancer-folder"].id
  depends_on = [yandex_lb_network_load_balancer.keepalived]
}
