resource "yandex_compute_instance" "wp-app" {
  name = "wp-app"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-20.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.wp-subnet-a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }


  provisioner "local-exec" {
    command = "echo \"The server's IP address is ${self.network_interface.0.nat_ip_address} \""
  }
}

# Ansible provision



# resource "null_resource" "ansible-install" {

#   triggers = {
#     always_run = "${timestamp()}"
#   }

  
# }