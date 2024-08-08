locals {
  vm_user            = "almalinux"
  ssh_private_key    = "~/.ssh/id_rsa"
  cloud_id           = var.yc_cloud
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

 
  master_count = "1"
  db_count     = "1"
  iscsi_count  = "0"
  be_count     = "2"
  lb_count     = "1"
 
}

resource "yandex_resourcemanager_folder" "folders" {
  for_each = local.folders
  name     = each.key
  cloud_id = local.cloud_id
}


resource "yandex_vpc_network" "vpc" {
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  name = local.vpc_name
}

data "yandex_vpc_network" "vpc" {
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  name = yandex_vpc_network.vpc.name
}



resource "yandex_vpc_subnet" "subnets" {
  for_each       = local.subnets
  name           = each.key
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  v4_cidr_blocks = each.value["v4_cidr_blocks"]
  zone           = local.zone
  network_id     = data.yandex_vpc_network.vpc.id
  route_table_id = yandex_vpc_route_table.rt.id
}


resource "yandex_vpc_gateway" "nat_gateway" {
  name      = "test-gateway"
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

module "masters" {
  source    = "./modules/instances"
  count     = local.master_count
  vm_name   = "master-${format("%02d", count.index + 1)}"
  vpc_name  = local.vpc_name
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
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
  user-data      = "#cloud-config\nwrite_files:\n- content: ${base64encode("master:\n- 127.0.0.1\nid: master-${format("%02d", count.index + 1)}")}\n  encoding: b64\n  path: /etc/salt/minion.d/minion.conf\n${file("cloud-init-salt-master.yml")}"
  secondary_disk = {}
}

data "yandex_compute_instance" "masters" {
  count      = length(module.masters)
  name       = module.masters[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.masters]
}

module "dbs" {
  source    = "./modules/instances"
  count     = local.db_count
  vm_name   = "db-${format("%02d", count.index + 1)}"
  vpc_name  = local.vpc_name
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
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
  user-data      = "#cloud-config\nwrite_files:\n- content: ${base64encode("master:\n- ${data.yandex_compute_instance.masters[0].network_interface[0].ip_address}\nid: db-${format("%02d", count.index + 1)}")}\n  encoding: b64\n  path: /etc/salt/minion.d/minion.conf\n${file("cloud-init-salt-minion.yml")}"
  secondary_disk = {}
  depends_on     = [data.yandex_compute_instance.masters]
}

data "yandex_compute_instance" "dbs" {
  count      = length(module.dbs)
  name       = module.dbs[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.dbs]
}

module "bes" {
  source    = "./modules/instances"
  count     = local.be_count
  vm_name   = "be-${format("%02d", count.index + 1)}"
  vpc_name  = local.vpc_name
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      #nat       = true
    }
    if subnet.name == "lab-subnet" #|| subnet.name == "be-subnet"
  }
  
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  user-data      = "#cloud-config\nwrite_files:\n- content: ${base64encode("master:\n- ${data.yandex_compute_instance.masters[0].network_interface[0].ip_address}\nid: be-${format("%02d", count.index + 1)}")}\n  encoding: b64\n  path: /etc/salt/minion.d/minion.conf\n${file("cloud-init-salt-minion.yml")}"
  secondary_disk = {}
  depends_on     = [data.yandex_compute_instance.masters]

}

data "yandex_compute_instance" "bes" {
  count      = length(module.bes)
  name       = module.bes[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.bes]
}

module "lbs" {
  source    = "./modules/instances"
  count     = local.lb_count
  vm_name   = "lb-${format("%02d", count.index + 1)}"
  vpc_name  = local.vpc_name
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat       = true
    }
    if subnet.name == "lab-subnet" #|| subnet.name == "lb-subnet"
  }

  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  user-data      = "#cloud-config\nwrite_files:\n- content: ${base64encode("master:\n- ${data.yandex_compute_instance.masters[0].network_interface[0].ip_address}\nid: lb-${format("%02d", count.index + 1)}")}\n  encoding: b64\n  path: /etc/salt/minion.d/minion.conf\n${file("cloud-init-salt-minion.yml")}"
  secondary_disk = {}
  depends_on = [data.yandex_compute_instance.masters]
}

data "yandex_compute_instance" "lbs" {
  count      = length(module.lbs)
  name       = module.lbs[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.lbs]
}

resource "local_file" "inventory_file" {
  content = templatefile("${path.module}/templates/inventory.tpl",
    {
      masters       = data.yandex_compute_instance.masters
      dbs           = data.yandex_compute_instance.dbs
      bes           = data.yandex_compute_instance.bes
      lbs           = data.yandex_compute_instance.lbs
      remote_user   = local.vm_user
    }
  )
  filename = "${path.module}/inventory.ini"
}

resource "local_file" "roster_file" {
  content = templatefile("${path.module}/templates/roster.tpl",
    {
      masters       = data.yandex_compute_instance.masters
      dbs           = data.yandex_compute_instance.dbs
      bes           = data.yandex_compute_instance.bes
      lbs           = data.yandex_compute_instance.lbs
      remote_user   = local.vm_user
    }
  )
  filename = "${path.module}/srv/salt/roster"
}