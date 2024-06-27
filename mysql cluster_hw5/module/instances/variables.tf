variable "folder_id" {
  type = string
}

variable "vpc_name" {
  type = string
  description = "VPC name"
}

variable "zone" {       
  type = string
  default = "ru-zone-central1-b"
  description = "zone"
}


variable "network_interface" {
  type        = map(map(string))
  default     = {}
  description = "Additional network interface to attache to the instance"
}

## VM parameters
variable "vm_name" {
  type        = string
  description = "VM name"
}

variable "cpu" {
  type        = number
  default     = 2
  description = "VM CPU count"
}

variable "memory" {
  type        = number
  default     = 2
  description = "VM RAM size"
}

variable "core_fraction" {
  type        = number
  default     = 100
  description = "Core fraction, default 100%"
}

variable "disk" {
  type = number
  default     = 10
  description = "VM Disk size"
}


variable "disk_type" {
  type        = string
  default     = "network-ssd"
  description = "Disk type"
}

variable "secondary_disk" {
    type        = map(map(string))
    default     = {}
    description = "Additional secondary disk to attache to the instance"
}

variable "allow_stopping_for_update" {
  description = "If true, allows Terraform to stop the instance in order to update its properties. If you try to update a property that requires stopping the instance without setting this field, the update will fail."
  type        = bool
  default     = true
}

variable "image_id" {
  type        = string
  default     = "fd84itfojin92kj38vmb" # almalinux-8-v20230925
  description = "Default image ID AlmaLinux 8"
}

variable "nat" {
  type    = bool
  default = true
}

variable "platform_id" {
  type = string
  default = "standard-v3"
}

variable "internal_ip_address" {
  type = string
  default = null
}

variable "nat_ip_address" {
  type = string
  default = null
}

variable "vm_user" {
  type        = string
  description = "vm user"
  default     = ""
}

variable "ssh_public_key" {
  type        = string
  default     = ""
  description = "cloud-config ssh public key"
}

variable "ssh_private_key" {
  type        = string
  default     = ""
  description = "cloud-config ssh private key"
}