# Yandex Cloud Managed Kafka Cluster

## Features

- Create a Managed Kafka cluster with predefined number of DB hosts
- Create a list of users and topics with permissions
- Create a Connectors
- Easy to use in other resources via outputs

## Kafka cluster definition

At first you need to create VPC network with three subnets!

Kafka module requires a following input variables:
 - VPC network id
 - VPC network subnets ids
 - Zones and brokers count

<b>Notes:</b>
1. `users` variable defines a list of separate users with a `permissions` list, which indicates to a list of topics and grants for each of them.

### Example

See the [HA cluster example](./examples/ha%20cluster/) for a three-zone, three-broker ZooKeeper cluster with a highly available topic, and the [many setting example](./examples/many%20setting/) for broad cluster/topic settings and a disposable S3 Sink connector.

### Provider 0.225.0 upgrade notes

- The legacy Kafka `3.5` default is preserved to avoid an implicit upgrade of existing clusters. Set `kafka_version = "3.9"` (or another currently supported version) explicitly for new clusters.
- `kraft_config = null` preserves legacy ZooKeeper selection: ZooKeeper is added when `brokers_count > 1` or more than one zone is selected. `kraft_config = {}` selects combined KRaft and only permits three brokers in one zone or one broker in each of three zones. Supplying `kraft_config.resources` selects dedicated KRaft controllers. KRaft requires Kafka 3.6+, and Kafka 4+ requires KRaft.
- Provider 0.225.0 marks `kafka_config.log_preallocate` and `topics[*].topic_config.preallocate` deprecated. The module still forwards them so existing configurations keep their behavior.
- `cluster_host_names_list` remains a deprecated nested legacy output. Use the new flat `cluster_host_names` output for new callers.
- Provider 0.225.0 exposes Kafka disk autoscaling in the schema, but live create and update requests both omit `disk_size_limit` and are rejected by the API. The many-setting example keeps this block visible behind `enable_disk_size_autoscaling = false`; the rest of the example is runnable while this provider defect remains.

### Configure Terraform for Yandex Cloud

- Install [YC CLI](https://cloud.yandex.com/docs/cli/quickstart)
- Add environment variables for terraform auth in Yandex.Cloud

```
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.2 |
| <a name="requirement_yandex"></a> [yandex](#requirement\_yandex) | >= 0.225.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) | 0.225.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [yandex_mdb_kafka_cluster.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/mdb_kafka_cluster) | resource |
| [yandex_mdb_kafka_connector.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/mdb_kafka_connector) | resource |
| [yandex_mdb_kafka_topic.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/mdb_kafka_topic) | resource |
| [yandex_mdb_kafka_user.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/mdb_kafka_user) | resource |
| [yandex_client_config.client](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_policy"></a> [access\_policy](#input\_access\_policy) | Access policy from other services to the Kafka cluster. | <pre>object({<br/>    data_transfer = optional(bool, null)<br/>  })</pre> | `{}` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Whether to assign public IP addresses to the instances. | `bool` | `true` | no |
| <a name="input_brokers_count"></a> [brokers\_count](#input\_brokers\_count) | The number of brokers. | `number` | n/a | yes |
| <a name="input_connectors"></a> [connectors](#input\_connectors) | A list of Kafka connectors to create. | <pre>list(object({<br/>    name       = string<br/>    tasks_max  = optional(number)<br/>    properties = optional(map(string))<br/>    connector_config_mirrormaker = optional(object({<br/>      topics             = string<br/>      replication_factor = number<br/>      source_cluster = object({<br/>        alias        = optional(string)<br/>        this_cluster = optional(object({}), null)<br/>        external_cluster = optional(object({<br/>          bootstrap_servers = string<br/>          sasl_username     = optional(string)<br/>          sasl_password     = optional(string)<br/>          sasl_mechanism    = optional(string)<br/>          security_protocol = optional(string)<br/>        }), null)<br/>      })<br/>      target_cluster = object({<br/>        alias        = optional(string)<br/>        this_cluster = optional(object({}), null)<br/>        external_cluster = optional(object({<br/>          bootstrap_servers = string<br/>          sasl_username     = optional(string)<br/>          sasl_password     = optional(string)<br/>          sasl_mechanism    = optional(string)<br/>          security_protocol = optional(string)<br/>        }), null)<br/>      })<br/>    }), null)<br/>    connector_config_s3_sink = optional(object({<br/>      topics                = string<br/>      file_compression_type = string<br/>      file_max_records      = optional(number)<br/>      s3_connection = object({<br/>        bucket_name = string<br/>        external_s3 = object({<br/>          endpoint          = string<br/>          access_key_id     = optional(string)<br/>          secret_access_key = optional(string)<br/>          region            = optional(string)<br/>        })<br/>      })<br/>    }), null)<br/>    connector_config_iceberg_sink = optional(object({<br/>      control_topic = optional(string)<br/>      topics        = optional(string, null)<br/>      topics_regex  = optional(string, null)<br/>      metastore_connection = object({<br/>        catalog_uri = string<br/>        warehouse   = string<br/>      })<br/>      s3_connection = object({<br/>        external_s3 = object({<br/>          endpoint          = string<br/>          access_key_id     = optional(string)<br/>          secret_access_key = optional(string)<br/>          region            = optional(string)<br/>        })<br/>      })<br/>      static_tables = optional(object({<br/>        tables = string<br/>      }), null)<br/>      dynamic_tables = optional(object({<br/>        route_field = string<br/>      }), null)<br/>      tables_config = optional(object({<br/>        default_commit_branch   = optional(string)<br/>        default_id_columns      = optional(string)<br/>        default_partition_by    = optional(string)<br/>        evolve_schema_enabled   = optional(bool)<br/>        schema_force_optional   = optional(bool)<br/>        schema_case_insensitive = optional(bool)<br/>      }), null)<br/>      control_config = optional(object({<br/>        commit_interval_ms   = optional(number)<br/>        commit_threads       = optional(number)<br/>        commit_timeout_ms    = optional(number)<br/>        group_id_prefix      = optional(string)<br/>        transactional_prefix = optional(string)<br/>      }), null)<br/>    }), null)<br/>  }))</pre> | `[]` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Inhibits deletion of the cluster. | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Kafka cluster description | `string` | `"Managed Kafka cluster created by terraform module"` | no |
| <a name="input_disk_encryption_key_id"></a> [disk\_encryption\_key\_id](#input\_disk\_encryption\_key\_id) | The ID of the KMS symmetric key used to encrypt Kafka cluster disks. | `string` | `null` | no |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | The size of the disk in GB. | `number` | `32` | no |
| <a name="input_disk_size_autoscaling"></a> [disk\_size\_autoscaling](#input\_disk\_size\_autoscaling) | Optional disk autoscaling settings for Kafka broker disks. disk\_size\_limit is in bytes. | <pre>object({<br/>    disk_size_limit           = number<br/>    planned_usage_threshold   = optional(number)<br/>    emergency_usage_threshold = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_disk_type_id"></a> [disk\_type\_id](#input\_disk\_type\_id) | The type of the disk. | `string` | `"network-ssd"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment for the Kafka cluster (e.g. PRESTABLE, PRODUCTION). | `string` | `"PRODUCTION"` | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | Folder ID that contains the Kafka cluster. | `string` | `null` | no |
| <a name="input_host_group_ids"></a> [host\_group\_ids](#input\_host\_group\_ids) | IDs of dedicated host groups on which to place Kafka cluster VMs. | `set(string)` | `null` | no |
| <a name="input_kafka_config"></a> [kafka\_config](#input\_kafka\_config) | The configuration for the Kafka broker. log\_preallocate is deprecated by provider 0.225.0 but remains forwarded for compatibility. | <pre>object({<br/>    compression_type                = optional(string)<br/>    auto_create_topics_enable       = optional(bool)<br/>    log_flush_interval_messages     = optional(number)<br/>    log_flush_interval_ms           = optional(number)<br/>    log_flush_scheduler_interval_ms = optional(number)<br/>    log_retention_bytes             = optional(number)<br/>    log_retention_hours             = optional(number)<br/>    log_retention_minutes           = optional(number)<br/>    log_retention_ms                = optional(number)<br/>    log_segment_bytes               = optional(number)<br/>    log_preallocate                 = optional(bool)<br/>    num_partitions                  = optional(number)<br/>    default_replication_factor      = optional(number)<br/>    message_max_bytes               = optional(number)<br/>    replica_fetch_max_bytes         = optional(number)<br/>    ssl_cipher_suites               = optional(list(string))<br/>    offsets_retention_minutes       = optional(number)<br/>    socket_send_buffer_bytes        = optional(number)<br/>    socket_receive_buffer_bytes     = optional(number)<br/>    sasl_enabled_mechanisms         = optional(list(string))<br/>    transactional_id_expiration_ms  = optional(number)<br/>    log_message_timestamp_type      = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_kafka_ui_enabled"></a> [kafka\_ui\_enabled](#input\_kafka\_ui\_enabled) | Whether to enable Kafka UI. | `bool` | `false` | no |
| <a name="input_kafka_version"></a> [kafka\_version](#input\_kafka\_version) | The Kafka version to use. The legacy 3.5 default is preserved to avoid upgrading existing clusters; set 3.9 or later explicitly for new clusters. | `string` | `"3.5"` | no |
| <a name="input_kraft_config"></a> [kraft\_config](#input\_kraft\_config) | Optional KRaft configuration. null keeps legacy ZooKeeper selection; {} selects combined KRaft; resources selects dedicated KRaft controllers. | <pre>object({<br/>    resources = optional(object({<br/>      resource_preset_id = string<br/>      disk_type_id       = string<br/>      disk_size          = number<br/>    }), null)<br/>  })</pre> | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | A set of label pairs to assing to the Kafka cluster. | `map(any)` | `{}` | no |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | (Optional) Maintenance policy of the Kafka cluster.<br/>      - type - (Required) Type of maintenance window. Can be either ANYTIME or WEEKLY. A day and hour of window need to be specified with weekly window.<br/>      - day  - (Optional) Day of the week (in DDD format). Allowed values: "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"<br/>      - hour - (Optional) Hour of the day in UTC (in HH format). Allowed value is between 1 and 24. | <pre>object({<br/>    type = string<br/>    day  = optional(string, null)<br/>    hour = optional(number, null)<br/>  })</pre> | <pre>{<br/>  "type": "ANYTIME"<br/>}</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the Kafka cluster. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | The ID of the VPC network where the cluster will be deployed. | `string` | n/a | yes |
| <a name="input_resource_preset_id"></a> [resource\_preset\_id](#input\_resource\_preset\_id) | The resource preset ID. | `string` | `"s3-c2-m8"` | no |
| <a name="input_rest_api_enabled"></a> [rest\_api\_enabled](#input\_rest\_api\_enabled) | Whether to enable the Managed Kafka REST API. | `bool` | `false` | no |
| <a name="input_schema_registry"></a> [schema\_registry](#input\_schema\_registry) | Whether to enable the schema registry. | `bool` | `false` | no |
| <a name="input_security_groups_ids_list"></a> [security\_groups\_ids\_list](#input\_security\_groups\_ids\_list) | A list of security group IDs to which the Kafka cluster belongs. | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | A list of subnet IDs to deploy the cluster in. | `list(string)` | n/a | yes |
| <a name="input_topics"></a> [topics](#input\_topics) | A list of Kafka topics to create. partitions and replication\_factor are required by the provider. topic\_config.preallocate is deprecated by provider 0.225.0 but remains forwarded for compatibility. | <pre>list(object({<br/>    name               = string<br/>    partitions         = number<br/>    replication_factor = number<br/>    topic_config = optional(object({<br/>      cleanup_policy         = optional(string)<br/>      compression_type       = optional(string)<br/>      delete_retention_ms    = optional(number)<br/>      file_delete_delay_ms   = optional(number)<br/>      flush_messages         = optional(number)<br/>      flush_ms               = optional(number)<br/>      min_compaction_lag_ms  = optional(number)<br/>      retention_bytes        = optional(number)<br/>      retention_ms           = optional(number)<br/>      max_message_bytes      = optional(number)<br/>      min_insync_replicas    = optional(number)<br/>      segment_bytes          = optional(number)<br/>      preallocate            = optional(bool)<br/>      message_timestamp_type = optional(string)<br/>    }), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_users"></a> [users](#input\_users) | A list of Kafka users to create. | <pre>list(object({<br/>    name     = string<br/>    password = optional(string)<br/>    permissions = optional(list(object({<br/>      topic_name  = string<br/>      role        = string<br/>      allow_hosts = optional(list(string), [])<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | A list of availability zones. | `list(string)` | n/a | yes |
| <a name="input_zookeeper_config"></a> [zookeeper\_config](#input\_zookeeper\_config) | The configuration for ZooKeeper nodes. | <pre>object({<br/>    resources = object({<br/>      resource_preset_id = optional(string, "s3-c2-m8")<br/>      disk_type_id       = optional(string, "network-ssd")<br/>      disk_size          = optional(number, 32)<br/>    })<br/>  })</pre> | <pre>{<br/>  "resources": {<br/>    "disk_size": 30,<br/>    "disk_type_id": "network-ssd",<br/>    "resource_preset_id": "s3-c2-m8"<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_host_names"></a> [cluster\_host\_names](#output\_cluster\_host\_names) | Flat list of Kafka cluster host names. |
| <a name="output_cluster_host_names_list"></a> [cluster\_host\_names\_list](#output\_cluster\_host\_names\_list) | Deprecated legacy nested host-name list. Retained unchanged for compatibility; use cluster\_host\_names for a flat list. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | Kafka cluster ID |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Kafka cluster name |
| <a name="output_connection_step_1"></a> [connection\_step\_1](#output\_connection\_step\_1) | 1 step - Install certificate |
| <a name="output_connection_step_2"></a> [connection\_step\_2](#output\_connection\_step\_2) | How connect to Kafka cluster?<br/><br/>    1. Run connection string from the output value, for example<br/><br/>      kafkacat -C \<br/>         -b <FQDN\_брокера>:9091 \<br/>         -t <имя\_топика> \<br/>         -X security.protocol=SASL\_SSL \<br/>         -X sasl.mechanism=SCRAM-SHA-512 \<br/>         -X sasl.username="<логин\_потребителя>" \<br/>         -X sasl.password="<пароль\_потребителя>" \<br/>         -X ssl.ca.location=/usr/local/share/ca-certificates/Yandex/YandexInternalRootCA.crt -Z -K: |
| <a name="output_topics"></a> [topics](#output\_topics) | A list of topics names. |
| <a name="output_users_data"></a> [users\_data](#output\_users\_data) | A list of users with passwords. |
<!-- END_TF_DOCS -->
