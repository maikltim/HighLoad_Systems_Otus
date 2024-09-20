variable "yc_token" {
  type = string
  sensitive = true
  description = "Yandex Cloud OAuth token"
}

variable "yc_cloud" {
  type = string
  description = "Yandex Cloud ID"
}

variable "zone" {
    type = string 
    default = "ru-central1-b"
}

variable "domain_name" {
  type = string
}