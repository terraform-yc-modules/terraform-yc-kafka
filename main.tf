### Datasource
data "yandex_client_config" "client" {}

### Locals
locals {
  folder_id           = var.folder_id == null ? data.yandex_client_config.client.folder_id : var.folder_id
  kafka_version_major = try(tonumber(split(".", var.kafka_version)[0]), 0)
  kafka_version_minor = try(tonumber(split(".", var.kafka_version)[1]), 0)
}

# Cluster
resource "yandex_mdb_kafka_cluster" "this" {
  name                   = var.name
  description            = var.description
  environment            = var.environment
  network_id             = var.network_id
  subnet_ids             = var.subnet_ids
  folder_id              = local.folder_id
  security_group_ids     = var.security_groups_ids_list
  deletion_protection    = var.deletion_protection
  disk_encryption_key_id = var.disk_encryption_key_id
  host_group_ids         = var.host_group_ids
  labels                 = var.labels

  config {
    version          = var.kafka_version
    brokers_count    = var.brokers_count
    zones            = var.zones
    assign_public_ip = var.assign_public_ip
    schema_registry  = var.schema_registry

    dynamic "disk_size_autoscaling" {
      for_each = var.disk_size_autoscaling == null ? [] : [var.disk_size_autoscaling]
      content {
        disk_size_limit           = disk_size_autoscaling.value.disk_size_limit
        planned_usage_threshold   = disk_size_autoscaling.value.planned_usage_threshold
        emergency_usage_threshold = disk_size_autoscaling.value.emergency_usage_threshold
      }
    }

    dynamic "rest_api" {
      for_each = var.rest_api_enabled ? [1] : []
      content {
        enabled = true
      }
    }

    dynamic "kafka_ui" {
      for_each = var.kafka_ui_enabled ? [1] : []
      content {
        enabled = true
      }
    }

    kafka {
      resources {
        resource_preset_id = var.resource_preset_id
        disk_type_id       = var.disk_type_id
        disk_size          = var.disk_size
      }
      kafka_config {
        compression_type                = var.kafka_config.compression_type
        auto_create_topics_enable       = var.kafka_config.auto_create_topics_enable
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
        socket_send_buffer_bytes        = var.kafka_config.socket_send_buffer_bytes
        socket_receive_buffer_bytes     = var.kafka_config.socket_receive_buffer_bytes
        transactional_id_expiration_ms  = var.kafka_config.transactional_id_expiration_ms
        log_message_timestamp_type      = var.kafka_config.log_message_timestamp_type
      }
    }
    dynamic "zookeeper" {
      for_each = var.kraft_config == null && (var.brokers_count > 1 || length(var.zones) > 1) ? [1] : []
      content {
        resources {
          resource_preset_id = var.zookeeper_config.resources.resource_preset_id
          disk_type_id       = var.zookeeper_config.resources.disk_type_id
          disk_size          = var.zookeeper_config.resources.disk_size
        }
      }
    }
    dynamic "kraft" {
      for_each = try(var.kraft_config.resources, null) == null ? [] : [var.kraft_config]
      content {
        resources {
          resource_preset_id = kraft.value.resources.resource_preset_id
          disk_type_id       = kraft.value.resources.disk_type_id
          disk_size          = kraft.value.resources.disk_size
        }
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

  lifecycle {
    precondition {
      condition     = var.kraft_config == null || local.kafka_version_major > 3 || (local.kafka_version_major == 3 && local.kafka_version_minor >= 6)
      error_message = "KRaft requires Kafka version 3.6 or later."
    }
    precondition {
      condition     = local.kafka_version_major < 4 || var.kraft_config != null
      error_message = "Kafka version 4.0 or later requires KRaft; set kraft_config to {} for combined mode or configure kraft_config.resources for dedicated controllers."
    }
    precondition {
      condition     = var.kraft_config == null ? true : (var.kraft_config.resources != null || ((length(var.zones) == 1 && var.brokers_count == 3) || (length(var.zones) == 3 && var.brokers_count == 1)))
      error_message = "Combined KRaft requires exactly three brokers: three in one availability zone, or one in each of three availability zones."
    }
    precondition {
      condition     = alltrue([for topic in var.topics : topic.replication_factor <= var.brokers_count * length(var.zones)])
      error_message = "Each topic replication_factor cannot exceed the cluster's total broker count."
    }
    precondition {
      condition     = alltrue([for topic in var.topics : topic.topic_config.min_insync_replicas == null ? true : topic.topic_config.min_insync_replicas <= topic.replication_factor])
      error_message = "topic_config.min_insync_replicas cannot exceed the topic replication_factor."
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
    cleanup_policy         = each.value.topic_config.cleanup_policy
    compression_type       = each.value.topic_config.compression_type
    delete_retention_ms    = each.value.topic_config.delete_retention_ms
    file_delete_delay_ms   = each.value.topic_config.file_delete_delay_ms
    flush_messages         = each.value.topic_config.flush_messages
    flush_ms               = each.value.topic_config.flush_ms
    min_compaction_lag_ms  = each.value.topic_config.min_compaction_lag_ms
    retention_bytes        = each.value.topic_config.retention_bytes
    retention_ms           = each.value.topic_config.retention_ms
    max_message_bytes      = each.value.topic_config.max_message_bytes
    min_insync_replicas    = each.value.topic_config.min_insync_replicas
    segment_bytes          = each.value.topic_config.segment_bytes
    preallocate            = each.value.topic_config.preallocate
    message_timestamp_type = each.value.topic_config.message_timestamp_type
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
    for_each = each.value.connector_config_mirrormaker == null ? [] : [each.value.connector_config_mirrormaker]
    content {
      topics             = connector_config_mirrormaker.value.topics
      replication_factor = connector_config_mirrormaker.value.replication_factor

      source_cluster {
        alias = connector_config_mirrormaker.value.source_cluster.alias

        dynamic "this_cluster" {
          for_each = connector_config_mirrormaker.value.source_cluster.this_cluster == null ? [] : [connector_config_mirrormaker.value.source_cluster.this_cluster]
          content {}
        }

        dynamic "external_cluster" {
          for_each = connector_config_mirrormaker.value.source_cluster.external_cluster == null ? [] : [connector_config_mirrormaker.value.source_cluster.external_cluster]
          content {
            bootstrap_servers = external_cluster.value.bootstrap_servers
            sasl_username     = external_cluster.value.sasl_username
            sasl_password     = external_cluster.value.sasl_password
            sasl_mechanism    = external_cluster.value.sasl_mechanism
            security_protocol = external_cluster.value.security_protocol
          }
        }
      }

      target_cluster {
        alias = connector_config_mirrormaker.value.target_cluster.alias

        dynamic "this_cluster" {
          for_each = connector_config_mirrormaker.value.target_cluster.this_cluster == null ? [] : [connector_config_mirrormaker.value.target_cluster.this_cluster]
          content {}
        }

        dynamic "external_cluster" {
          for_each = connector_config_mirrormaker.value.target_cluster.external_cluster == null ? [] : [connector_config_mirrormaker.value.target_cluster.external_cluster]
          content {
            bootstrap_servers = external_cluster.value.bootstrap_servers
            sasl_username     = external_cluster.value.sasl_username
            sasl_password     = external_cluster.value.sasl_password
            sasl_mechanism    = external_cluster.value.sasl_mechanism
            security_protocol = external_cluster.value.security_protocol
          }
        }
      }
    }
  }

  dynamic "connector_config_s3_sink" {
    for_each = each.value.connector_config_s3_sink == null ? [] : [each.value.connector_config_s3_sink]
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
          region            = connector_config_s3_sink.value.s3_connection.external_s3.region
        }
      }
    }
  }

  dynamic "connector_config_iceberg_sink" {
    for_each = each.value.connector_config_iceberg_sink == null ? [] : [each.value.connector_config_iceberg_sink]
    content {
      control_topic = connector_config_iceberg_sink.value.control_topic
      topics        = connector_config_iceberg_sink.value.topics
      topics_regex  = connector_config_iceberg_sink.value.topics_regex

      metastore_connection {
        catalog_uri = connector_config_iceberg_sink.value.metastore_connection.catalog_uri
        warehouse   = connector_config_iceberg_sink.value.metastore_connection.warehouse
      }

      s3_connection {
        external_s3 {
          endpoint          = connector_config_iceberg_sink.value.s3_connection.external_s3.endpoint
          access_key_id     = connector_config_iceberg_sink.value.s3_connection.external_s3.access_key_id
          secret_access_key = connector_config_iceberg_sink.value.s3_connection.external_s3.secret_access_key
          region            = connector_config_iceberg_sink.value.s3_connection.external_s3.region
        }
      }

      dynamic "static_tables" {
        for_each = connector_config_iceberg_sink.value.static_tables == null ? [] : [connector_config_iceberg_sink.value.static_tables]
        content {
          tables = static_tables.value.tables
        }
      }

      dynamic "dynamic_tables" {
        for_each = connector_config_iceberg_sink.value.dynamic_tables == null ? [] : [connector_config_iceberg_sink.value.dynamic_tables]
        content {
          route_field = dynamic_tables.value.route_field
        }
      }

      dynamic "tables_config" {
        for_each = connector_config_iceberg_sink.value.tables_config == null ? [] : [connector_config_iceberg_sink.value.tables_config]
        content {
          default_commit_branch   = tables_config.value.default_commit_branch
          default_id_columns      = tables_config.value.default_id_columns
          default_partition_by    = tables_config.value.default_partition_by
          evolve_schema_enabled   = tables_config.value.evolve_schema_enabled
          schema_force_optional   = tables_config.value.schema_force_optional
          schema_case_insensitive = tables_config.value.schema_case_insensitive
        }
      }

      dynamic "control_config" {
        for_each = connector_config_iceberg_sink.value.control_config == null ? [] : [connector_config_iceberg_sink.value.control_config]
        content {
          commit_interval_ms   = control_config.value.commit_interval_ms
          commit_threads       = control_config.value.commit_threads
          commit_timeout_ms    = control_config.value.commit_timeout_ms
          group_id_prefix      = control_config.value.group_id_prefix
          transactional_prefix = control_config.value.transactional_prefix
        }
      }
    }
  }
}
