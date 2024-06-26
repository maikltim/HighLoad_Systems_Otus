locals {
  vm_user            = "cloud-user"
  zone = "ru-central1-b"
  ssh_public_key  = "~/.ssh/id_rsa.pub"
  ssh_private_key = "~/.ssh/id_rsa"
  vpc_name = "my_vpc_network"
  subnet_cidrs = ["10.10.20.0/24"]
  subnet_name = "my_vpc_subnet"
  disks = {
    "data" = {
      "size"  = "1"
    }
  }
}


resource "yandex_vpc_network" "vpc" {
  name = local.vpc_name
}

resource "yandex_vpc_subnet" "subnet" {
  v4_cidr_blocks = local.subnet_cidrs
  zone = local.zone
  name = local.subnet_name
  network_id = yandex_vpc_network.vpc.id
}


module "iscsi-servers" {
  source = "./modules/instances"
  count = 1
  vm_name = "iscsi-${format("%02d", count.index + 1)}"
  vpc_name = local.vpc_name
  subnet_cidrs = yandex_vpc_subnet.subnet.v4_cidr_blocks
  subnet_name = yandex_vpc_subnet.subnet.name
  subnet_id = yandex_vpc_subnet.subnet.id
  vm_user = local.vm_user
  ssh_public_key = local.ssh_public_key

  secondary_disk = {
    for disk in data.yandex_compute_disk.disks :
    disk.name => {
      disk_id     = disk.id
    }
    if disk.name == "data" #or disk.name == "var"
  }
  depends_on = [ yandex_compute_disk.disks ]
}

data "yandex_compute_instance" "iscsi-servers" {
  count = length(module.iscsi-servers)
  name = module.iscsi-servers[count.index].vm_name
  depends_on = [module.iscsi-servers]
}

module "pcs-servers" {
  source = "./modules/instances"
  count = 3
  vm_name = "pcs-${format("%02d", count.index + 1)}"
  vpc_name = local.vpc_name
  subnet_cidrs = yandex_vpc_subnet.subnet.v4_cidr_blocks
  subnet_name = yandex_vpc_subnet.subnet.name
  subnet_id = yandex_vpc_subnet.subnet.id
  vm_user = local.vm_user
  ssh_public_key = local.ssh_public_key
  depends_on = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "pcs-servers" {
  count = length(module.pcs-servers)
  name = module.pcs-servers[count.index].vm_name
  depends_on = [module.pcs-servers]
}


resource "local_file" "inventory_file" {
  content = templatefile("${path.module}/templates/inventory.tpl",
  {
    iscsi-servers = data.yandex_compute_instance.iscsi-servers
    pcs-servers = data.yandex_compute_instance.pcs-servers
  }
  )
  filename = "${path.module}/inventory.ini"
}


resource "local_file" "group_vars_all_file" {
  content = templatefile("${path.module}/templates/group_vars_all.tpl",
    {
      iscsi-servers = data.yandex_compute_instance.iscsi-servers
      pcs-servers   = data.yandex_compute_instance.pcs-servers
      subnet_cidrs  = local.subnet_cidrs
    }
  )
  filename = "${path.module}/group_vars/all/main.yml"
}

resource "yandex_compute_disk" "disks" {
  for_each = local.disks
  name = each.key
  size = each.value["size"]
  zone = local.zone
}

data "yandex_compute_disk" "disks" {
  for_each = yandex_compute_disk.disks
  name = each.value["name"]
  depends_on = [yandex_compute_disk.disks]
}