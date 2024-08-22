### Datasource
data "yandex_client_config" "client" {}

### Locals
locals {
  folder_id = var.folder_id == null ? data.yandex_client_config.client.folder_id : var.folder_id
}

# Cluster
resource "yandex_mdb_kafka_cluster" "this" {
  name                = var.name
  description         = var.description
  environment         = var.environment
  network_id          = var.network_id
  subnet_ids          = var.subnet_ids
  folder_id           = local.folder_id
  security_group_ids  = var.security_groups_ids_list
  deletion_protection = var.deletion_protection
  labels              = var.labels

  config {
    version          = var.kafka_version
    brokers_count    = var.brokers_count
    zones            = var.zones
    assign_public_ip = var.assign_public_ip
    schema_registry  = var.schema_registry

    kafka {
      resources {
        resource_preset_id = var.resource_preset_id
        disk_type_id       = var.disk_type_id
        disk_size          = var.disk_size
      }
      kafka_config {
        compression_type                = var.kafka_config.compression_type
        log_flush_interval_messages     = var.kafka_config.log_flush_interval_messages
        log_flush_interval_ms           = var.kafka_config.log_flush_interval_ms
        log_flush_scheduler_interval_ms = var.kafka_config.log_flush_scheduler_interval_ms
        log_retention_bytes             = var.kafka_config.log_retention_bytes
        log_retention_hours             = var.kafka_config.log_retention_hours
        log_retention_minutes           = var.kafka_config.log_retention_minutes
        log_retention_ms                = var.kafka_config.log_retention_ms
        log_segment_bytes               = var.kafka_config.log_segment_bytes
        log_preallocate                 = var.kafka_config.log_preallocate
        num_partitions                  = var.kafka_config.num_partitions
        default_replication_factor      = var.kafka_config.default_replication_factor
        message_max_bytes               = var.kafka_config.message_max_bytes
        replica_fetch_max_bytes         = var.kafka_config.replica_fetch_max_bytes
        ssl_cipher_suites               = var.kafka_config.ssl_cipher_suites
        offsets_retention_minutes       = var.kafka_config.offsets_retention_minutes
        sasl_enabled_mechanisms         = var.kafka_config.sasl_enabled_mechanisms
      }
    }
    zookeeper {
      resources {
        resource_preset_id = var.zookeeper_config.resources.resource_preset_id
        disk_type_id       = var.zookeeper_config.resources.disk_type_id
        disk_size          = var.zookeeper_config.resources.disk_size
      }
    }
    dynamic "access" {
      for_each = range(var.access_policy == null ? 0 : 1)
      content {
        data_transfer = var.access_policy.data_transfer
      }
    }
  }

  dynamic "maintenance_window" {
    for_each = range(var.maintenance_window == null ? 0 : 1)
    content {
      type = var.maintenance_window.type
      day  = var.maintenance_window.day
      hour = var.maintenance_window.hour
    }
  }
}

#Topics
resource "yandex_mdb_kafka_topic" "this" {
  for_each           = { for topic in var.topics : topic.name => topic }
  cluster_id         = yandex_mdb_kafka_cluster.this.id
  name               = each.value.name
  partitions         = each.value.partitions
  replication_factor = each.value.replication_factor

  topic_config {
    cleanup_policy        = each.value.topic_config.cleanup_policy
    compression_type      = each.value.topic_config.compression_type
    delete_retention_ms   = each.value.topic_config.delete_retention_ms
    file_delete_delay_ms  = each.value.topic_config.file_delete_delay_ms
    flush_messages        = each.value.topic_config.flush_messages
    flush_ms              = each.value.topic_config.flush_ms
    min_compaction_lag_ms = each.value.topic_config.min_compaction_lag_ms
    retention_bytes       = each.value.topic_config.retention_bytes
    retention_ms          = each.value.topic_config.retention_ms
    max_message_bytes     = each.value.topic_config.max_message_bytes
    min_insync_replicas   = each.value.topic_config.min_insync_replicas
    segment_bytes         = each.value.topic_config.segment_bytes
    preallocate           = each.value.topic_config.preallocate
  }
}

#Users
resource "random_password" "password" {
  for_each         = { for v in var.users : v.name => v if v.password == null }
  length           = 16
  special          = true
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "_"
}
resource "yandex_mdb_kafka_user" "this" {
  for_each   = { for user in var.users : user.name => user }
  cluster_id = yandex_mdb_kafka_cluster.this.id
  name       = each.value.name
  password   = each.value.password == null ? random_password.password[each.value.name].result : each.value.password

  dynamic "permission" {
    for_each = each.value.permissions
    content {
      topic_name  = permission.value.topic_name
      role        = permission.value.role
      allow_hosts = permission.value.allow_hosts
    }
  }
}

#Connectors
resource "yandex_mdb_kafka_connector" "this" {
  for_each   = { for connector in var.connectors : connector.name => connector }
  cluster_id = yandex_mdb_kafka_cluster.this.id
  name       = each.value.name
  tasks_max  = lookup(each.value, "tasks_max", null)
  properties = each.value.properties

  dynamic "connector_config_mirrormaker" {
    for_each = lookup(each.value, "connector_config_mirrormaker", [])
    content {
      topics             = connector_config_mirrormaker.value.topics
      replication_factor = lookup(connector_config_mirrormaker.value, "replication_factor", null)

      source_cluster {
        alias = connector_config_mirrormaker.value.source_cluster.alias

        external_cluster {
          bootstrap_servers = connector_config_mirrormaker.value.source_cluster.external_cluster.bootstrap_servers
          sasl_username     = lookup(connector_config_mirrormaker.value.source_cluster.external_cluster, "sasl_username", null)
          sasl_password     = lookup(connector_config_mirrormaker.value.source_cluster.external_cluster, "sasl_password", null)
          sasl_mechanism    = lookup(connector_config_mirrormaker.value.source_cluster.external_cluster, "sasl_mechanism", null)
          security_protocol = lookup(connector_config_mirrormaker.value.source_cluster.external_cluster, "security_protocol", null)
        }
      }

      target_cluster {
        alias = connector_config_mirrormaker.value.target_cluster.alias

        dynamic "this_cluster" {
          for_each = lookup(connector_config_mirrormaker.value.target_cluster, "this_cluster", [])
          content {}
        }

        dynamic "external_cluster" {
          for_each = lookup(connector_config_mirrormaker.value.target_cluster, "external_cluster", [])
          content {
            bootstrap_servers = external_cluster.value.bootstrap_servers
            sasl_username     = lookup(external_cluster.value, "sasl_username", null)
            sasl_password     = lookup(external_cluster.value, "sasl_password", null)
            sasl_mechanism    = lookup(external_cluster.value, "sasl_mechanism", null)
            security_protocol = lookup(external_cluster.value, "security_protocol", null)
          }
        }
      }
    }
  }

  dynamic "connector_config_s3_sink" {
    for_each = lookup(each.value, "connector_config_s3_sink", [])
    content {
      topics                = connector_config_s3_sink.value.topics
      file_compression_type = connector_config_s3_sink.value.file_compression_type
      file_max_records      = connector_config_s3_sink.value.file_max_records

      s3_connection {
        bucket_name = connector_config_s3_sink.value.s3_connection.bucket_name
        external_s3 {
          endpoint          = connector_config_s3_sink.value.s3_connection.external_s3.endpoint
          access_key_id     = connector_config_s3_sink.value.s3_connection.external_s3.access_key_id
          secret_access_key = connector_config_s3_sink.value.s3_connection.external_s3.secret_access_key
        }
      }
    }
  }
}
