# Many settings example

This disposable example enables the broadest set of settings that can be
verified using only Yandex Cloud resources: dedicated KRaft controllers, KMS
disk encryption, Schema Registry, REST API, Kafka UI, broker/topic settings,
user permissions, and an S3 Sink connector backed by a private Object Storage
bucket.

The following provider features remain explicit opt-ins:

- `use_combined_kraft`: plans three brokers in one zone with combined KRaft
  instead of the cheaper default with dedicated KRaft controllers.
- `enable_disk_size_autoscaling`: provider 0.225.0 exposes the block but does
  not serialize `disk_size_limit`, so the API rejects create and update calls.
- `enable_mirrormaker_connector`: requires reachable external Kafka bootstrap
  servers and valid SASL credentials.
- `enable_iceberg_connector`: requires a reachable Hive Metastore. The example
  reuses its disposable Object Storage bucket and service account.

Dedicated host groups are intentionally omitted because they require
pre-existing paid infrastructure.
