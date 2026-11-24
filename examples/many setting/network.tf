resource "yandex_vpc_network" "this" {
  name = "kafka-many-settings-network"
}

resource "yandex_vpc_subnet" "this" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = ["10.42.0.0/24"]
}

resource "yandex_vpc_security_group" "this" {
  name        = "kafka-many-settings-sg"
  description = "Security group for the many-settings Kafka example"
  network_id  = yandex_vpc_network.this.id

  ingress {
    protocol       = "TCP"
    description    = "Kafka TLS from the example VPC subnet"
    port           = 9091
    v4_cidr_blocks = ["10.42.0.0/24"]
  }

  egress {
    protocol       = "ANY"
    description    = "Required outbound traffic"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_kms_symmetric_key" "this" {
  name              = "kafka-many-settings-key"
  default_algorithm = "AES_256"
  rotation_period   = "8760h"
}

resource "yandex_iam_service_account" "this" {
  name        = "kafka-many-settings-s3"
  description = "Disposable S3 Sink connector access for the Kafka example"
}

resource "yandex_resourcemanager_folder_iam_member" "this" {
  folder_id = data.yandex_client_config.this.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.this.id}"
}

resource "yandex_iam_service_account_static_access_key" "this" {
  service_account_id = yandex_iam_service_account.this.id
  description        = "Disposable key for the Kafka many-settings S3 Sink connector"

  depends_on = [yandex_resourcemanager_folder_iam_member.this]
}

resource "yandex_storage_bucket" "this" {
  bucket_prefix = "kafka-many-settings-"
  folder_id     = data.yandex_client_config.this.folder_id
  force_destroy = true

  anonymous_access_flags {
    read = false
    list = false
  }
}

data "yandex_client_config" "this" {}
