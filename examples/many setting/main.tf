# This example exercises a broad set of cluster and topic settings plus an S3
# Sink connector. MirrorMaker and Iceberg are included as opt-in configurations
# because their successful apply requires external Kafka/metastore services.
module "kafka" {
  source = "../../"

  name                     = "kafka-many-settings"
  description              = "Managed Kafka example exercising module settings"
  environment              = "PRESTABLE"
  network_id               = yandex_vpc_network.this.id
  subnet_ids               = [yandex_vpc_subnet.this.id]
  zones                    = ["ru-central1-a"]
  brokers_count            = var.use_combined_kraft ? 3 : 1
  assign_public_ip         = true
  security_groups_ids_list = [yandex_vpc_security_group.this.id]
  disk_encryption_key_id   = yandex_kms_symmetric_key.this.id
  deletion_protection      = false
  schema_registry          = true
  rest_api_enabled         = true
  kafka_ui_enabled         = true
  resource_preset_id       = "s2.micro"
  disk_type_id             = "network-ssd"
  disk_size                = 32
  kafka_version            = "3.9"

  labels = {
    example = "many-settings"
  }

  # Provider 0.225.0 accepts this block in its schema but omits disk_size_limit
  # from both create and update API requests. Keep it opt-in until that provider
  # defect is fixed; the remaining settings form a runnable cloud example.
  disk_size_autoscaling = var.enable_disk_size_autoscaling ? {
    disk_size_limit           = 64 * 1024 * 1024 * 1024
    planned_usage_threshold   = 70
    emergency_usage_threshold = 90
  } : null

  kraft_config = var.use_combined_kraft ? {} : {
    resources = {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 20
    }
  }

  access_policy = {
    data_transfer = true
  }

  kafka_config = {
    auto_create_topics_enable       = false
    compression_type                = "COMPRESSION_TYPE_ZSTD"
    default_replication_factor      = 1
    log_flush_interval_messages     = 1024
    log_flush_interval_ms           = 1000
    log_flush_scheduler_interval_ms = 1000
    log_message_timestamp_type      = "MESSAGE_TIMESTAMP_TYPE_LOG_APPEND_TIME"
    log_retention_bytes             = 1073741824
    log_retention_hours             = 168
    log_retention_minutes           = 10080
    log_retention_ms                = 604800000
    log_segment_bytes               = 134217728
    message_max_bytes               = 1048588
    num_partitions                  = 3
    offsets_retention_minutes       = 10080
    replica_fetch_max_bytes         = 1048576
    sasl_enabled_mechanisms         = ["SASL_MECHANISM_SCRAM_SHA_256", "SASL_MECHANISM_SCRAM_SHA_512"]
    socket_receive_buffer_bytes     = 102400
    socket_send_buffer_bytes        = 102400
    ssl_cipher_suites               = ["TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"]
    transactional_id_expiration_ms  = 604800000
  }

  maintenance_window = {
    type = "WEEKLY"
    day  = "MON"
    hour = 1
  }

  topics = [
    {
      name               = "events"
      partitions         = 3
      replication_factor = 1
      topic_config = {
        cleanup_policy         = "CLEANUP_POLICY_DELETE"
        compression_type       = "COMPRESSION_TYPE_ZSTD"
        delete_retention_ms    = 86400000
        file_delete_delay_ms   = 60000
        flush_messages         = 1024
        flush_ms               = 1000
        max_message_bytes      = 1048588
        message_timestamp_type = "MESSAGE_TIMESTAMP_TYPE_LOG_APPEND_TIME"
        min_compaction_lag_ms  = 0
        min_insync_replicas    = 1
        retention_bytes        = 1073741824
        retention_ms           = 604800000
        segment_bytes          = 134217728
      }
    }
  ]

  users = [
    {
      name = "example-user"
      permissions = [
        {
          topic_name  = "events"
          role        = "ACCESS_ROLE_CONSUMER"
          allow_hosts = ["10.42.0.0/24"]
        },
        {
          topic_name = "events"
          role       = "ACCESS_ROLE_PRODUCER"
        },
      ]
    }
  ]

  connectors = concat([
    {
      name      = "events-s3-sink"
      tasks_max = 1
      properties = {
        "key.converter"                  = "org.apache.kafka.connect.storage.StringConverter"
        "value.converter"                = "org.apache.kafka.connect.json.JsonConverter"
        "value.converter.schemas.enable" = "false"
      }
      connector_config_s3_sink = {
        topics                = "events"
        file_compression_type = "gzip"
        file_max_records      = 100
        s3_connection = {
          bucket_name = yandex_storage_bucket.this.bucket
          external_s3 = {
            endpoint = "https://storage.yandexcloud.net"
            # The connector uses the AWS SDK region enum. Yandex Object Storage
            # also accepts its default AWS region for S3-compatible clients.
            region            = "us-east-1"
            access_key_id     = yandex_iam_service_account_static_access_key.this.access_key
            secret_access_key = yandex_iam_service_account_static_access_key.this.secret_key
          }
        }
      }
    }
    ],
    var.enable_mirrormaker_connector ? [{
      name      = "events-mirror"
      tasks_max = 1
      connector_config_mirrormaker = {
        topics             = "events"
        replication_factor = 1
        source_cluster = {
          this_cluster = {}
        }
        target_cluster = {
          external_cluster = {
            bootstrap_servers = var.mirrormaker_bootstrap_servers
            sasl_username     = var.mirrormaker_sasl_username
            sasl_password     = var.mirrormaker_sasl_password
            sasl_mechanism    = "SCRAM-SHA-512"
            security_protocol = "SASL_SSL"
          }
        }
      }
    }] : [],
    var.enable_iceberg_connector ? [{
      name      = "events-iceberg-sink"
      tasks_max = 1
      connector_config_iceberg_sink = {
        control_topic = "events-iceberg-control"
        topics        = "events"
        metastore_connection = {
          catalog_uri = var.iceberg_metastore_uri
          warehouse   = "s3a://${yandex_storage_bucket.this.bucket}/warehouse"
        }
        s3_connection = {
          external_s3 = {
            endpoint          = "https://storage.yandexcloud.net"
            region            = "us-east-1"
            access_key_id     = yandex_iam_service_account_static_access_key.this.access_key
            secret_access_key = yandex_iam_service_account_static_access_key.this.secret_key
          }
        }
        static_tables = {
          tables = "events:analytics.events"
        }
        tables_config = {
          default_commit_branch   = "main"
          default_id_columns      = "id"
          default_partition_by    = "event_date"
          evolve_schema_enabled   = true
          schema_force_optional   = true
          schema_case_insensitive = true
        }
        control_config = {
          commit_interval_ms   = 60000
          commit_threads       = 2
          commit_timeout_ms    = 300000
          group_id_prefix      = "events-iceberg"
          transactional_prefix = "events-iceberg"
        }
      }
    }] : []
  )
}
