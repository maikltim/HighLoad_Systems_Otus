locals {
  vm_user            = "cloud-user"
  cloud_id           = var.yc_cloud
  ssh_private_key    = "~/.ssh/id_rsa"
  ssh_public_key     = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  vpc_name           = "my_vpc_network"
  zone               = "ru-central1-b"
  
  folders = {
    "lab-folder" = {}
  }
    subnets = {
    "lab-subnet" = {
        v4_cidr_blocks = ["10.10.10.0/24"]
    }
  }

 
  jump_count     = "0"
  db_count       = "1"
  iscsi_count    = "1"
  backend_count  = "2"
  nginx_count    = "2"
  consul_count   = "3"
 
}

resource "yandex_resourcemanager_folder" "folders" {
  for_each = local.folders
  name     = each.key
  cloud_id = local.cloud_id
}

resource "yandex_vpc_network" "vpc" {
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  name      = local.vpc_name
}

data "yandex_vpc_network" "vpc" {
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  name      = yandex_vpc_network.vpc.name
}


resource "yandex_vpc_subnet" "subnets" {
  for_each = local.subnets
  name           = each.key
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  v4_cidr_blocks = each.value["v4_cidr_blocks"]
  zone           = local.zone
  network_id     = data.yandex_vpc_network.vpc.id
  route_table_id = yandex_vpc_route_table.rt.id
}


resource "yandex_vpc_gateway" "nat_gateway" {
  name = "test-gateway"
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "test-route-table"
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_id = yandex_vpc_network.vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

module "jump-servers" {
  source         = "./modules/instances"
  count          = local.jump_count
  vm_name        = "jump-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat       = true
    }
    if subnet.name == "lab-subnet"
  }
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "jump-servers" {
  count      = length(module.jump-servers)
  name       = module.jump-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.jump-servers]
}


module "db-servers" {
  source         = "./modules/instances"
  count          = local.db_count
  vm_name        = "db-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      #nat       = true
    }
    if subnet.name == "lab-subnet"
  }
  
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "db-servers" {
  count      = length(module.db-servers)
  name       = module.db-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.db-servers]
}

module "iscsi-servers" {
  source         = "./modules/instances"
  count          = local.iscsi_count
  vm_name        = "iscsi-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
    }
    if subnet.name == "lab-subnet" #|| subnet.name == "backend-subnet"
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
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.iscsi-servers]
}


module "backend-servers" {
  source         = "./modules/instances"
  count          = local.backend_count
  vm_name        = "backend-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
    }
    if subnet.name == "lab-subnet" #|| subnet.name == "backend-subnet"
  }
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "backend-servers" {
  count      = length(module.backend-servers)
  name       = module.backend-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.backend-servers]
}


module "nginx-servers" {
  source         = "./modules/instances"
  count          = local.nginx_count
  vm_name        = "nginx-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat       = true
    }
    if subnet.name == "lab-subnet" #|| subnet.name == "nginx-subnet"
  }
  
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "nginx-servers" {
  count      = length(module.nginx-servers)
  name       = module.nginx-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.nginx-servers]
}


module "consul-servers" {
  source         = "./modules/instances"
  count          = local.consul_count
  vm_name        = "consul-${format("%02d", count.index + 1)}"
  cpu            = 2
  memory         = 2
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
    }
    if subnet.name == "lab-subnet" #|| subnet.name == "nginx-subnet"
  }
  
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "consul-servers" {
  count      = length(module.consul-servers)
  name       = module.consul-servers[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.consul-servers]
}

resource "local_file" "inventory_file" {
  content = templatefile("${path.module}/templates/inventory.tpl",
    {
      jump-servers    = data.yandex_compute_instance.jump-servers
      db-servers      = data.yandex_compute_instance.db-servers
      iscsi-servers   = data.yandex_compute_instance.iscsi-servers
      backend-servers = data.yandex_compute_instance.backend-servers
      nginx-servers   = data.yandex_compute_instance.nginx-servers
      consul-servers  = data.yandex_compute_instance.consul-servers
      remote_user     = local.vm_user
      domain_name     = var.domain_name
      domain_org      = var.domain_org
      domain_token    = var.yc_token
    }
  )
  filename = "${path.module}/inventory.ini"
}

resource "yandex_compute_disk" "disks" {
  count     = local.iscsi_count
  name      = "web-${format("%02d", count.index + 1)}"
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  size      = "1"
  zone      = local.zone
}