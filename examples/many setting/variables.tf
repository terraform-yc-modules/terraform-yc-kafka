variable "enable_disk_size_autoscaling" {
  description = "Enable disk autoscaling after the Yandex provider starts serializing disk_size_limit for Kafka create/update requests."
  type        = bool
  default     = false
}

variable "use_combined_kraft" {
  description = "Use three brokers in one zone with combined KRaft instead of a broker with dedicated KRaft controllers."
  type        = bool
  default     = false
}

variable "enable_mirrormaker_connector" {
  description = "Create the opt-in MirrorMaker connector after configuring its external target cluster."
  type        = bool
  default     = false
}

variable "mirrormaker_bootstrap_servers" {
  description = "Bootstrap servers of the external MirrorMaker target cluster."
  type        = string
  default     = "broker.example:9092"
}

variable "mirrormaker_sasl_username" {
  description = "SASL username of the external MirrorMaker target cluster."
  type        = string
  default     = "example"
}

variable "mirrormaker_sasl_password" {
  description = "SASL password of the external MirrorMaker target cluster."
  type        = string
  sensitive   = true
  default     = "replace-me"
}

variable "enable_iceberg_connector" {
  description = "Create the opt-in Iceberg Sink connector after configuring an external Hive Metastore."
  type        = bool
  default     = false
}

variable "iceberg_metastore_uri" {
  description = "Thrift URI of the external Hive Metastore used by Iceberg Sink."
  type        = string
  default     = "thrift://metastore.example:9083"
}
