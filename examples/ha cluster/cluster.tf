module "kafka" {
  source = "../../"

  security_groups_ids_list = [yandex_vpc_security_group.db_sg.id, ]

  network_id = yandex_vpc_network.vpc.id
  subnet_ids = [yandex_vpc_subnet.sub_a.id, yandex_vpc_subnet.sub_b.id, yandex_vpc_subnet.sub_d.id, ]
  zones      = ["ru-central1-a", "ru-central1-b", "ru-central1-d"]
  kafka_config = {
    compression_type = "COMPRESSION_TYPE_ZSTD"
  }
  connectors = []
  topics = [
    {
      name               = "events"
      partitions         = 2
      replication_factor = 2
    }
  ]

  users = [
    {
      name = "test1-owner"
      permissions = [
        { "topic_name" : "events"
        "role" : "ACCESS_ROLE_CONSUMER" }
      ]
    },
  ]

  maintenance_window = {
    type : "ANYTIME"
  }

}
