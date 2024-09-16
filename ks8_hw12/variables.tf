variable "yc_cloud" {
  type = string
  description = "Yandex Cloud ID"
}

variable "yc_token" {
  type = string
  description = "Yandex Cloud OAuth token"
}

variable "zone" {
  type    = string
  default = "ru-central1-b"
}