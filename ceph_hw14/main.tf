locals {
  vm_user            = "almlinux"
  ssh_public_key     = "~/.ssh/id_rsa.pub"
  ssh_private_key    = "~/.ssh/id_rsa"
  vpc_name           = "my_vpc_network"


  folders = {
    "lab-folder" = {}
  }

  subnets = {
    "lab-subnet" = {
      v4_cidr_blocks = ["10.10.10.0/24"]
    }
  }

  osd_count    = "4"
  mds_count    = "1"
  mon_count    = "3"
  client_count = "1"
  disks_count  = "3"
}

resource "yandex_resourcemanager_folder" "folders" {
  for_each = local.folders
  name     = each.key
  cloud_id = var.yc_cloud
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
    name = each.key
    folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
    v4_cidr_blocks = each.value["v4_cidr_blocks"]
    zone        = var.zone
    network_id = data.yandex_vpc_network.vpc.id
    route_table_id = yandex_vpc_route_table.rt.id
}


resource "yandex_vpc_gateway" "nat_gateway" {
  name = "test-gateway"
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  shared_egress_gateway {}
}


resource "yandex_vpc_route_table" "rt" {
  name = "test-route-table"
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_id = yandex_vpc_network.vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id = yandex_vpc_gateway.nat_gateway.id
  }
}

module "mon" {
  source = "./modules/instances"
  count = local.mon_count
  vm_name = "mon-${format("%02d", count.index + 1)}"
  vpc_name = local.vpc_name
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat = count.index==0 ? true : false
    }
    if subnet.name == "lab-subnet"
  }
  vm_user = local.vm_user
  ssh_public_key = local.ssh_public_key
  user-data      = count.index != 0 ? "#cloud-config\nssh_authorized_keys:\n- ${tls_private_key.ceph_key.public_key_openssh}" : "#cloud-config\nhostname: mon-01\nwrite_files:\n- path: /home/${local.vm_user}/.ssh/id_rsa\n  defer: true\n  permissions: 0600\n  owner: ${local.vm_user}:${local.vm_user}\n  encoding: b64\n  content: ${base64encode("${tls_private_key.ceph_key.private_key_openssh}")}\n- path: /home/${local.vm_user}/.ssh/id_rsa.pub\n  defer: true\n  permissions: 0600\n  owner: ${local.vm_user}:${local.vm_user}\n  encoding: b64\n  content: ${base64encode("${tls_private_key.ceph_key.public_key_openssh}")}"

  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}


data "yandex_compute_instance" "mon" {
    count = length(module.mon)
    name = module.mon[count.index].vm_name
    folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
    depends_on = [module.mon]
}


module "mds" {
  source = "./modules/instances"
  count = local.mds_count
  vm_name        = "mds-${format("%02d", count.index + 1)}"
  vpc_name = local.vpc_name
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
    }
    if subnet.name == "lab-subnet"
  }
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  user-data      = "#cloud-config\nssh_authorized_keys:\n- ${tls_private_key.ceph_key.public_key_openssh}"
  secondary_disk = {}
  depends_on = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "mds" {
  count      = length(module.mds)
  name       = module.mds[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.mds]
}

module "osd" {
  source         = "./modules/instances"
  count          = local.osd_count
  vm_name        = "osd-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      
    }
    if subnet.name == "lab-subnet"
  }
  

  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  user-data      = "#cloud-config\nssh_authorized_keys:\n- ${tls_private_key.ceph_key.public_key_openssh}"
  secondary_disk = {
   
    
    for disk in yandex_compute_disk.disks :
    disk.name => {
      disk_id = disk.id
      
    }
    if "${substr(disk.name,0,6)}" == "osd-${format("%02d", count.index + 1)}"
  }
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "osd" {
  count      = length(module.osd)
  name       = module.osd[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.osd]
}


resource "yandex_compute_disk" "disks" {
  count     = local.osd_count * local.disks_count
  name      = "osd-${format("%02d", floor(count.index / local.disks_count) + 1)}-disk-${format("%02d", count.index % local.disks_count + 1)}"
  folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  size      = "10"
  zone      = var.zone
}


module "client" {
  source         = "./modules/instances"
  count          = local.client_count
  vm_name        = "client-${format("%02d", count.index + 1)}"
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
  user-data      = "#cloud-config\nssh_authorized_keys:\n- ${tls_private_key.ceph_key.public_key_openssh}"
  secondary_disk = {}
  depends_on = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "client" {
  count      = length(module.client)
  name       = module.client[count.index].vm_name
  folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.client]
}

resource "local_file" "inventory_file" {
  content = templatefile("${path.module}/templates/inventory.tpl",
    {
      mon         = data.yandex_compute_instance.mon
      mds         = data.yandex_compute_instance.mds
      osd         = data.yandex_compute_instance.osd
      client      = data.yandex_compute_instance.client
      remote_user = local.vm_user
      domain_name = var.domain_name
    }
  )
  filename = "${path.module}/inventory.ini"
}

resource "local_file" "inintial_ceph_file" {
  content = templatefile("${path.module}/templates/initial-config-primary-cluster.yaml.tpl",
    {
      mon         = data.yandex_compute_instance.mon
      mds         = data.yandex_compute_instance.mds
      osd         = data.yandex_compute_instance.osd
      client      = data.yandex_compute_instance.client
      domain_name = var.domain_name
    }
  )
  filename = "${path.module}/roles/ceph_setup/files/initial-config-primary-cluster.yaml"
}

resource "tls_private_key" "ceph_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
