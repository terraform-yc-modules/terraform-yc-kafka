
variable "name" {
  description = "The name of the Kafka cluster."
  type        = string
  default     = "kafka-cluster"
}

variable "folder_id" {
  description = "Folder id that contains the MongoDB cluster"
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
  description = "The Kafka version to use."
  type        = string
  default     = "2.8"
}

variable "brokers_count" {
  description = "The number of brokers."
  type        = number
  default     = 1
}

variable "security_groups_ids_list" {
  description = "A list of security group IDs to which the MongoDB cluster belongs"
  type        = list(string)
  default     = []
  nullable    = true
}

variable "maintenance_window" {
  description = <<EOF
    (Optional) Maintenance policy of the MongoDB cluster.
      - type - (Required) Type of maintenance window. Can be either ANYTIME or WEEKLY. A day and hour of window need to be specified with weekly window.
      - day  - (Optional) Day of the week (in DDD format). Allowed values: "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"
      - hour - (Optional) Hour of the day in UTC (in HH format). Allowed value is between 0 and 23.
  EOF
  type = object({
    type = string
    day  = optional(string, null)
    hour = optional(string, null)
  })
  default = {
    type = "ANYTIME"
  }
}

variable "deletion_protection" {
  description = "Inhibits deletion of the cluster."
  type        = bool
  default     = false
}

variable "zones" {
  description = "A list of availability zones."
  type        = list(string)
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

variable "resource_preset_id" {
  description = "The resource preset ID."
  type        = string
  default     = "s3-c3-m8"
}

variable "disk_type_id" {
  description = "The type of the disk."
  type        = string
  default     = "network-ssd"
}

variable "disk_size" {
  description = "The size of the disk in GB."
  type        = number
  default     = 40
}

variable "kafka_config" {
  description = "The configuration for the Kafka broker."
  type = object({
    compression_type          = optional(string, "COMPRESSION_TYPE_PRODUCER")
    auto_create_topics_enable = optional(bool, false)
    #! Проверить
    log_flush_interval_messages     = optional(number, 100)
    log_flush_interval_ms           = optional(number, 1000)
    log_flush_scheduler_interval_ms = optional(number, 1000)
    log_retention_bytes             = optional(number, -1)
    log_retention_hours             = optional(number, 168)
    log_retention_minutes           = optional(number, -1)
    log_retention_ms                = optional(number, -1)
    log_segment_bytes               = optional(number, 1073741824)
    log_preallocate                 = optional(bool, false)
    num_partitions                  = optional(number, 1)
    default_replication_factor      = optional(number, 1)
    message_max_bytes               = optional(number, 1048588)
    replica_fetch_max_bytes         = optional(number, 1048588)
    ssl_cipher_suites               = optional(list(string), [])
    offsets_retention_minutes       = optional(number, 10080)
    socket_send_buffer_bytes        = optional(number, -1)
    socket_receive_buffer_bytes     = optional(number, -1)
    sasl_enabled_mechanisms         = optional(list(string), ["SASL_MECHANISM_SCRAM_SHA_256", "SASL_MECHANISM_SCRAM_SHA_512"])
  })
  default = {}
}

variable "zookeeper_config" {
  description = "The configuration for ZooKeeper nodes."
  type = object({
    resources = object({
      resource_preset_id = optional(string, "s3-c3-m8")
      disk_type_id       = optional(string, "network-ssd")
      disk_size          = optional(number, 30)
    })
  })
  default = {
    resources = {
      resource_preset_id = "s3-c3-m8"
      disk_type_id       = "network-ssd"
      disk_size          = 30
    }
  }

}

variable "access_policy" {
  description = "Access policy from other services to the MongoDB cluster."
  type = object({
    data_transfer = optional(bool, null)
  })
  default = {}
}

variable "topics" {
  description = "A list of Kafka topics to create."
  type = list(object({
    name               = string
    partitions         = number
    replication_factor = number
    topic_config = object({
      cleanup_policy        = string
      compression_type      = string
      delete_retention_ms   = number
      file_delete_delay_ms  = number
      flush_messages        = number
      flush_ms              = number
      min_compaction_lag_ms = number
      retention_bytes       = number
      retention_ms          = number
      max_message_bytes     = number
      min_insync_replicas   = number
      segment_bytes         = number
      preallocate           = bool
    })
  }))
}

variable "users" {
  description = "A list of Kafka users to create."
  type = list(object({
    name     = string
    password = string
    permissions = list(object({
      topic_name  = string
      role        = string
      allow_hosts = list(string)
    }))
  }))
}

variable "connectors" {
  description = "A list of Kafka connectors to create."
  type = list(object({
    name       = string
    tasks_max  = optional(number)
    properties = map(string)
    connector_config_mirrormaker = optional(object({
      topics             = string
      replication_factor = optional(number)
      source_cluster = object({
        alias = string
        external_cluster = object({
          bootstrap_servers = string
          sasl_username     = optional(string)
          sasl_password     = optional(string)
          sasl_mechanism    = optional(string)
          security_protocol = optional(string)
        })
      })
      target_cluster = object({
        alias        = string
        this_cluster = optional(object({}))
        external_cluster = optional(object({
          bootstrap_servers = string
          sasl_username     = optional(string)
          sasl_password     = optional(string)
          sasl_mechanism    = optional(string)
          security_protocol = optional(string)
        }))
      })
    }))
    connector_config_s3_sink = optional(object({
      topics                = string
      file_compression_type = string
      file_max_records      = number
      s3_connection = object({
        bucket_name = string
        external_s3 = object({
          endpoint          = string
          access_key_id     = string
          secret_access_key = string
        })
      })
    }))
  }))
}
