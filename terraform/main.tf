terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

provider "docker" {}
provider "local" {}
provider "null" {}

# Provision the Docker container
resource "docker_image" "ubuntu" {
  name = "ubuntu:24.04"
}

resource "docker_container" "nginx_server" {
  name  = "nginx_server"
  image = docker_image.ubuntu.image_id

  # Ports and volumes (same as earlier)
  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 22
    external = 2222
  }
  volumes {
    host_path      = abspath("../ansible/images")
    container_path = "/var/www/html/images"
  }
}

# Generate Ansible inventory dynamically
resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory"
  content  = <<-EOT
    [webserver]
    ${docker_container.nginx_server.name} ansible_host=127.0.0.1 ansible_port=2222 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
  EOT
}

# Trigger Ansible after Terraform provisions the container
resource "null_resource" "ansible_provisioner" {
  depends_on = [docker_container.nginx_server, local_file.ansible_inventory]

  provisioner "local-exec" {
    command = <<-EOT
      cd ../ansible &&
      ANSIBLE_VAULT_PASSWORD_FILE=../terraform/vault_password \
      ansible-playbook -i inventory playbook.yml
    EOT
  }
}