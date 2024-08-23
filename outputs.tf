output "cluster_id" {
  description = "Kafka cluster ID"
  value       = yandex_mdb_kafka_cluster.this.id
}

output "cluster_name" {
  description = "Kafka cluster name"
  value       = yandex_mdb_kafka_cluster.this.name
}

output "cluster_host_names_list" {
  description = "Kafka cluster host name"
  value       = [yandex_mdb_kafka_cluster.this.host[*].name]
}

output "users_data" {
  sensitive   = true
  description = "A list of users with passwords."
  value = [
    for u in yandex_mdb_kafka_user.this : {
      user     = u["name"]
      password = u["password"]
    }
  ]
}

output "topics" {
  description = "A list of topics names."
  value       = [for v in var.topics : v.name]
}

output "connection_step_1" {
  description = "1 step - Install certificate"
  value       = "mkdir -p /usr/local/share/ca-certificates/Yandex/ && wget 'https://storage.yandexcloud.net/cloud-certs/CA.pem' --output-document /usr/local/share/ca-certificates/Yandex/YandexInternalRootCA.crt && chmod 0655 /usr/local/share/ca-certificates/Yandex/YandexInternalRootCA.crt"
}

output "connection_step_2" {
  description = <<EOF
    How connect to Kafka cluster?

    1. Run connection string from the output value, for example
    
      kafkacat -C \
         -b <FQDN_брокера>:9091 \
         -t <имя_топика> \
         -X security.protocol=SASL_SSL \
         -X sasl.mechanism=SCRAM-SHA-512 \
         -X sasl.username="<логин_потребителя>" \
         -X sasl.password="<пароль_потребителя>" \
         -X ssl.ca.location=/usr/local/share/ca-certificates/Yandex/YandexInternalRootCA.crt -Z -K:
  EOF
  value       = "kafkacat -C -b <FQDN_брокера>:9091 -t <имя_топика> -X security.protocol=SASL_SSL -X sasl.mechanism=SCRAM-SHA-512 -X sasl.username=' < логин_потребителя > ' -X sasl.password=' < пароль_потребителя > ' -X ssl.ca.location=/usr/local/share/ca-certificates/Yandex/YandexInternalRootCA.crt -Z -K:"
}
