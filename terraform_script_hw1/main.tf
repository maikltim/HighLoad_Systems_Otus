locals { 
  user            = "debian"
  ssh_private_key = "~/.ssh/id_rsa"
}

resource "yandex_compute_instance" "this" {
  name = "test"
  platform_id = "standard-v1"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd83u9thmahrv9lgedrk"
      size = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.this.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }


provisioner "remote-exec" {
      inline = ["echo It is alive!"]
  
      connection {
        host        = self.network_interface.0.nat_ip_address
        type        = "ssh"
        user        = local.user
        private_key = file(local.ssh_private_key)
        #agent       = true
      }
  }

  provisioner "local-exec" {
    command = "ansible-playbook -u '${local.user}' --private-key '${local.ssh_private_key}' --become -i '${self.network_interface.0.nat_ip_address},' ansible/playbook.yml"

    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }

  }

}




