
variable "name" {
  description = "The name of the Kafka cluster."
  type        = string
}

variable "folder_id" {
  description = "Folder ID that contains the Kafka cluster."
  type        = string
  default     = null
}

variable "description" {
  description = "Kafka cluster description"
  type        = string
  default     = "Managed Kafka cluster created by terraform module"
}

variable "environment" {
  description = "The environment for the Kafka cluster (e.g. PRESTABLE, PRODUCTION)."
  type        = string
  default     = "PRODUCTION"
  validation {
    condition     = contains(["PRODUCTION", "PRESTABLE"], var.environment)
    error_message = "Release channel should be PRODUCTION (stable feature set) or PRESTABLE (early bird feature access)."
  }
}

variable "network_id" {
  description = "The ID of the VPC network where the cluster will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs to deploy the cluster in."
  type        = list(string)
}

variable "kafka_version" {
  description = "The Kafka version to use. The legacy 3.5 default is preserved to avoid upgrading existing clusters; set 3.9 or later explicitly for new clusters."
  type        = string
  default     = "3.5"
}

variable "brokers_count" {
  description = "The number of brokers."
  type        = number
  validation {
    condition     = var.brokers_count >= 1 && floor(var.brokers_count) == var.brokers_count
    error_message = "brokers_count must be a positive whole number."
  }
}

variable "security_groups_ids_list" {
  description = "A list of security group IDs to which the Kafka cluster belongs."
  type        = list(string)
  default     = []
  nullable    = true
}

variable "maintenance_window" {
  description = <<EOF
    (Optional) Maintenance policy of the Kafka cluster.
      - type - (Required) Type of maintenance window. Can be either ANYTIME or WEEKLY. A day and hour of window need to be specified with weekly window.
      - day  - (Optional) Day of the week (in DDD format). Allowed values: "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"
      - hour - (Optional) Hour of the day in UTC (in HH format). Allowed value is between 1 and 24.
  EOF
  type = object({
    type = string
    day  = optional(string, null)
    hour = optional(number, null)
  })
  default = {
    type = "ANYTIME"
  }
  validation {
    condition = contains(["ANYTIME", "WEEKLY"], var.maintenance_window.type) && (
      var.maintenance_window.type == "ANYTIME" ? true : (
        var.maintenance_window.day != null &&
        contains(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], var.maintenance_window.day) &&
        var.maintenance_window.hour != null &&
        var.maintenance_window.hour >= 1 && var.maintenance_window.hour <= 24 &&
        floor(var.maintenance_window.hour) == var.maintenance_window.hour
      )
    )
    error_message = "maintenance_window must be ANYTIME, or WEEKLY with day MON..SUN and hour 1..24."
  }
}

variable "deletion_protection" {
  description = "Inhibits deletion of the cluster."
  type        = bool
  default     = false
}

variable "disk_encryption_key_id" {
  description = "The ID of the KMS symmetric key used to encrypt Kafka cluster disks."
  type        = string
  default     = null
}

variable "host_group_ids" {
  description = "IDs of dedicated host groups on which to place Kafka cluster VMs."
  type        = set(string)
  default     = null
}

variable "zones" {
  description = "A list of availability zones."
  type        = list(string)
  validation {
    condition     = length(var.zones) > 0
    error_message = "At least one availability zone is required."
  }
}

variable "assign_public_ip" {
  description = "Whether to assign public IP addresses to the instances."
  type        = bool
  default     = true
}

variable "labels" {
  description = "A set of label pairs to assing to the Kafka cluster."
  type        = map(any)
  default     = {}
}

variable "schema_registry" {
  description = "Whether to enable the schema registry."
  type        = bool
  default     = false
}

variable "rest_api_enabled" {
  description = "Whether to enable the Managed Kafka REST API."
  type        = bool
  default     = false
}

variable "kafka_ui_enabled" {
  description = "Whether to enable Kafka UI."
  type        = bool
  default     = false
}

variable "disk_size_autoscaling" {
  description = "Optional disk autoscaling settings for Kafka broker disks. disk_size_limit is in bytes."
  type = object({
    disk_size_limit           = number
    planned_usage_threshold   = optional(number)
    emergency_usage_threshold = optional(number)
  })
  default = null
  validation {
    condition = var.disk_size_autoscaling == null ? true : (
      var.disk_size_autoscaling.disk_size_limit > 0 &&
      (var.disk_size_autoscaling.planned_usage_threshold == null ? true : (var.disk_size_autoscaling.planned_usage_threshold >= 0 && var.disk_size_autoscaling.planned_usage_threshold <= 100)) &&
      (var.disk_size_autoscaling.emergency_usage_threshold == null ? true : (var.disk_size_autoscaling.emergency_usage_threshold >= 0 && var.disk_size_autoscaling.emergency_usage_threshold <= 100)) &&
      (var.disk_size_autoscaling.planned_usage_threshold == null || var.disk_size_autoscaling.emergency_usage_threshold == null ? true : var.disk_size_autoscaling.planned_usage_threshold <= var.disk_size_autoscaling.emergency_usage_threshold)
    )
    error_message = "Autoscaling thresholds must be between 0 and 100, and planned_usage_threshold cannot exceed emergency_usage_threshold."
  }
}

variable "resource_preset_id" {
  description = "The resource preset ID."
  type        = string
  default     = "s3-c2-m8"
}

variable "disk_type_id" {
  description = "The type of the disk."
  type        = string
  default     = "network-ssd"
}

variable "disk_size" {
  description = "The size of the disk in GB."
  type        = number
  default     = 32
}

variable "kafka_config" {
  description = "The configuration for the Kafka broker. log_preallocate is deprecated by provider 0.225.0 but remains forwarded for compatibility."
  type = object({
    compression_type                = optional(string)
    auto_create_topics_enable       = optional(bool)
    log_flush_interval_messages     = optional(number)
    log_flush_interval_ms           = optional(number)
    log_flush_scheduler_interval_ms = optional(number)
    log_retention_bytes             = optional(number)
    log_retention_hours             = optional(number)
    log_retention_minutes           = optional(number)
    log_retention_ms                = optional(number)
    log_segment_bytes               = optional(number)
    log_preallocate                 = optional(bool)
    num_partitions                  = optional(number)
    default_replication_factor      = optional(number)
    message_max_bytes               = optional(number)
    replica_fetch_max_bytes         = optional(number)
    ssl_cipher_suites               = optional(list(string))
    offsets_retention_minutes       = optional(number)
    socket_send_buffer_bytes        = optional(number)
    socket_receive_buffer_bytes     = optional(number)
    sasl_enabled_mechanisms         = optional(list(string))
    transactional_id_expiration_ms  = optional(number)
    log_message_timestamp_type      = optional(string)
  })
  default = {}
  validation {
    condition = var.kafka_config.log_message_timestamp_type == null ? true : contains([
      "MESSAGE_TIMESTAMP_TYPE_CREATE_TIME",
      "MESSAGE_TIMESTAMP_TYPE_LOG_APPEND_TIME",
    ], var.kafka_config.log_message_timestamp_type)
    error_message = "log_message_timestamp_type must be MESSAGE_TIMESTAMP_TYPE_CREATE_TIME or MESSAGE_TIMESTAMP_TYPE_LOG_APPEND_TIME."
  }
}

variable "kraft_config" {
  description = "Optional KRaft configuration. null keeps legacy ZooKeeper selection; {} selects combined KRaft; resources selects dedicated KRaft controllers."
  type = object({
    resources = optional(object({
      resource_preset_id = string
      disk_type_id       = string
      disk_size          = number
    }), null)
  })
  default = null
}

variable "zookeeper_config" {
  description = "The configuration for ZooKeeper nodes."
  type = object({
    resources = object({
      resource_preset_id = optional(string, "s3-c2-m8")
      disk_type_id       = optional(string, "network-ssd")
      disk_size          = optional(number, 32)
    })
  })
  default = {
    resources = {
      resource_preset_id = "s3-c2-m8"
      disk_type_id       = "network-ssd"
      disk_size          = 30
    }
  }
}

variable "access_policy" {
  description = "Access policy from other services to the Kafka cluster."
  type = object({
    data_transfer = optional(bool, null)
  })
  default = {}
}

variable "topics" {
  description = "A list of Kafka topics to create. partitions and replication_factor are required by the provider. topic_config.preallocate is deprecated by provider 0.225.0 but remains forwarded for compatibility."
  type = list(object({
    name               = string
    partitions         = number
    replication_factor = number
    topic_config = optional(object({
      cleanup_policy         = optional(string)
      compression_type       = optional(string)
      delete_retention_ms    = optional(number)
      file_delete_delay_ms   = optional(number)
      flush_messages         = optional(number)
      flush_ms               = optional(number)
      min_compaction_lag_ms  = optional(number)
      retention_bytes        = optional(number)
      retention_ms           = optional(number)
      max_message_bytes      = optional(number)
      min_insync_replicas    = optional(number)
      segment_bytes          = optional(number)
      preallocate            = optional(bool)
      message_timestamp_type = optional(string)
    }), {})
  }))
  default = []
  validation {
    condition     = alltrue([for topic in var.topics : topic.partitions >= 1 && floor(topic.partitions) == topic.partitions && topic.replication_factor >= 1 && floor(topic.replication_factor) == topic.replication_factor])
    error_message = "Topic partitions and replication_factor must be positive whole numbers."
  }
  validation {
    condition     = alltrue([for topic in var.topics : topic.topic_config.message_timestamp_type == null ? true : contains(["MESSAGE_TIMESTAMP_TYPE_CREATE_TIME", "MESSAGE_TIMESTAMP_TYPE_LOG_APPEND_TIME"], topic.topic_config.message_timestamp_type)])
    error_message = "topic_config.message_timestamp_type must be MESSAGE_TIMESTAMP_TYPE_CREATE_TIME or MESSAGE_TIMESTAMP_TYPE_LOG_APPEND_TIME."
  }
}

variable "users" {
  description = "A list of Kafka users to create."
  type = list(object({
    name     = string
    password = optional(string)
    permissions = optional(list(object({
      topic_name  = string
      role        = string
      allow_hosts = optional(list(string), [])
    })), [])
  }))
  default = []

}

variable "connectors" {
  description = "A list of Kafka connectors to create."
  type = list(object({
    name       = string
    tasks_max  = optional(number)
    properties = optional(map(string))
    connector_config_mirrormaker = optional(object({
      topics             = string
      replication_factor = number
      source_cluster = object({
        alias        = optional(string)
        this_cluster = optional(object({}), null)
        external_cluster = optional(object({
          bootstrap_servers = string
          sasl_username     = optional(string)
          sasl_password     = optional(string)
          sasl_mechanism    = optional(string)
          security_protocol = optional(string)
        }), null)
      })
      target_cluster = object({
        alias        = optional(string)
        this_cluster = optional(object({}), null)
        external_cluster = optional(object({
          bootstrap_servers = string
          sasl_username     = optional(string)
          sasl_password     = optional(string)
          sasl_mechanism    = optional(string)
          security_protocol = optional(string)
        }), null)
      })
    }), null)
    connector_config_s3_sink = optional(object({
      topics                = string
      file_compression_type = string
      file_max_records      = optional(number)
      s3_connection = object({
        bucket_name = string
        external_s3 = object({
          endpoint          = string
          access_key_id     = optional(string)
          secret_access_key = optional(string)
          region            = optional(string)
        })
      })
    }), null)
    connector_config_iceberg_sink = optional(object({
      control_topic = optional(string)
      topics        = optional(string, null)
      topics_regex  = optional(string, null)
      metastore_connection = object({
        catalog_uri = string
        warehouse   = string
      })
      s3_connection = object({
        external_s3 = object({
          endpoint          = string
          access_key_id     = optional(string)
          secret_access_key = optional(string)
          region            = optional(string)
        })
      })
      static_tables = optional(object({
        tables = string
      }), null)
      dynamic_tables = optional(object({
        route_field = string
      }), null)
      tables_config = optional(object({
        default_commit_branch   = optional(string)
        default_id_columns      = optional(string)
        default_partition_by    = optional(string)
        evolve_schema_enabled   = optional(bool)
        schema_force_optional   = optional(bool)
        schema_case_insensitive = optional(bool)
      }), null)
      control_config = optional(object({
        commit_interval_ms   = optional(number)
        commit_threads       = optional(number)
        commit_timeout_ms    = optional(number)
        group_id_prefix      = optional(string)
        transactional_prefix = optional(string)
      }), null)
    }), null)
  }))
  default = []
  validation {
    condition = alltrue([for connector in var.connectors : length(compact([
      connector.connector_config_mirrormaker == null ? null : "mirrormaker",
      connector.connector_config_s3_sink == null ? null : "s3_sink",
      connector.connector_config_iceberg_sink == null ? null : "iceberg_sink",
    ])) == 1])
    error_message = "Each connector must configure exactly one of connector_config_mirrormaker, connector_config_s3_sink, or connector_config_iceberg_sink."
  }
  validation {
    condition = alltrue([for connector in var.connectors : connector.connector_config_mirrormaker == null ? true : (
      ((connector.connector_config_mirrormaker.source_cluster.this_cluster == null ? 0 : 1) + (connector.connector_config_mirrormaker.source_cluster.external_cluster == null ? 0 : 1) == 1) &&
      ((connector.connector_config_mirrormaker.target_cluster.this_cluster == null ? 0 : 1) + (connector.connector_config_mirrormaker.target_cluster.external_cluster == null ? 0 : 1) == 1)
    )])
    error_message = "MirrorMaker source_cluster and target_cluster must each select exactly one of this_cluster or external_cluster."
  }
  validation {
    condition = alltrue([for connector in var.connectors : connector.connector_config_iceberg_sink == null ? true : (
      ((connector.connector_config_iceberg_sink.topics == null ? 0 : 1) + (connector.connector_config_iceberg_sink.topics_regex == null ? 0 : 1) == 1) &&
      ((connector.connector_config_iceberg_sink.static_tables == null ? 0 : 1) + (connector.connector_config_iceberg_sink.dynamic_tables == null ? 0 : 1) == 1)
    )])
    error_message = "Iceberg Sink must select exactly one of topics or topics_regex and exactly one of static_tables or dynamic_tables."
  }
}
