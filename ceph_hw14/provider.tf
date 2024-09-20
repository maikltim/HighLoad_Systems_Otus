provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud
}

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}