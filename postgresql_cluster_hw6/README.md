# реализация кластера postgreSQL с помощью patroni

## Описание/Пошаговая инструкция выполнения домашнего задания:

> Перевести БД веб проекта на кластер postgreSQL с ипользованием patroni, etcd/consul/zookeeper и haproxy/pgbouncer.


# Выполнение домашнего задания

## Создание стенда

> Стенд будем разворачивать с помощью Terraform на YandexCloud, настройку серверов будем выполнять с помощью Ansible.

### Рзворачиваем стенд

```
terraform apply -auto-approve

ansible-playbook ./provision.yml
```

> На всех серверах будут установлены ОС Almalinux 8, настроены смнхронизация времени Chrony, система принудительного контроля доступа SELinux, в качестве
> firewall будет использоваться NFTables.
> Стенд был взят из mysql-cluster_hw5, только вместо одного сервера для базы данных, будет кластер, состоящий из серверов db-01, db-02 и db-03. Для создания
> кластера базы данных будем использовать кластер PostgreSQL с ипользованием Patroni, ETCD и HAProxy.

> Так как на YandexCloud ограничено количество выделяемых публичных IP адресов, в дополнение к этому стенду создадим ещё один сервер jump-01 в качестве
> JumpHost, через который будем подключаться по SSH (в частности для Ansible) к другим серверам той же подсети.

> Список виртуальных машин после запуска стенда:

> С помощью ssh через jump-сервер jump-01 подключися к какому-либо сервера PostgreSQL кластера, например, db-02:

```
# [member]
ETCD_NAME=etcd2
ETCD_DATA_DIR="/var/lib/etcd"
#ETCD_WAL_DIR=""
#ETCD_SNAPSHOT_COUNT="10000"
ETCD_HEARTBEAT_INTERVAL="100"
ETCD_ELECTION_TIMEOUT="5000"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
#ETCD_CORS=""
#
#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.10.10.9:2380"
# if you use different ETCD_NAME (e.g. test), set ETCD_INITIAL_CLUSTER value for this name, i.e. "test=http://..."
ETCD_INITIAL_CLUSTER="etcd1=http://10.10.10.17:2380,etcd2=http://10.10.10.9:2380,etcd3=http://10.10.10.32:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="PgsqlCluster"
ETCD_ADVERTISE_CLIENT_URLS="http://10.10.10.9:2379"
#ETCD_DISCOVERY=""
#ETCD_DISCOVERY_SRV=""
#ETCD_DISCOVERY_FALLBACK="proxy"
#ETCD_DISCOVERY_PROXY=""
ETCD_ENABLE_V2="true"
#ETCD_STRICT_RECONFIG_CHECK="false"
#ETCD_AUTO_COMPACTION_RETENTION="0"
#
#[proxy]
#ETCD_PROXY="off"
#ETCD_PROXY_FAILURE_WAIT="5000"
#ETCD_PROXY_REFRESH_INTERVAL="30000"
#ETCD_PROXY_DIAL_TIMEOUT="1000"
#ETCD_PROXY_WRITE_TIMEOUT="5000"
#ETCD_PROXY_READ_TIMEOUT="0"
#
#[security]
#ETCD_CERT_FILE=""
#ETCD_KEY_FILE=""
#ETCD_CLIENT_CERT_AUTH="false"
#ETCD_TRUSTED_CA_FILE=""
#ETCD_AUTO_TLS="false"
#ETCD_PEER_CERT_FILE=""
#ETCD_PEER_KEY_FILE=""
#ETCD_PEER_CLIENT_CERT_AUTH="false"
#ETCD_PEER_TRUSTED_CA_FILE=""
#ETCD_PEER_AUTO_TLS="false"
#
```

```
etcdctl endpoint status --write-out=table --endpoints=10.10.10.9:2380,10.10.10.17:2380,10.10.10.32:2380
+------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|     ENDPOINT     |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|  10.10.10.9:2380 | 3656fe2bc1869ac5 |  3.5.13 |   20 kB |      true |      false |         2 |       1198 |               1198 |        |
| 10.10.10.17:2380 | 4c96cf9e482df2b0 |  3.5.13 |   20 kB |     false |      false |         2 |       1198 |               1198 |        |
| 10.10.10.32:2380 |  9c99bcca9bbbc59 |  3.5.13 |   20 kB |     false |      false |         2 |       1198 |               1198 |        |
+------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

> Конфигурация Patroni:

```
scope: PgsqlCluster
#namespace: /service/
name: etcd2

restapi:
  listen: 10.10.10.9:8008
  connect_address: 10.10.10.9:8008
#  cafile: /etc/ssl/certs/ssl-cacert-snakeoil.pem
#  certfile: /etc/ssl/certs/ssl-cert-snakeoil.pem
#  keyfile: /etc/ssl/private/ssl-cert-snakeoil.key
#  authentication:
#    username: username
#    password: password

#ctl:
#  insecure: false # Allow connections to Patroni REST API without verifying certificates
#  certfile: /etc/ssl/certs/ssl-cert-snakeoil.pem
#  keyfile: /etc/ssl/private/ssl-cert-snakeoil.key
#  cacert: /etc/ssl/certs/ssl-cacert-snakeoil.pem

#citus:
#  database: citus
#  group: 0  # coordinator

etcd:
  #Provide host to do the initial discovery of the cluster topology:
  hosts: 10.10.10.17:2379,10.10.10.9:2379,10.10.10.32:2379
  #Or use "hosts" to provide multiple endpoints
  #Could be a comma separated string:
  #hosts: host1:port1,host2:port2
  #or an actual yaml list:
  #hosts:
  #- host1:port1
  #- host2:port2
  #Once discovery is complete Patroni will use the list of advertised clientURLs
  #It is possible to change this behavior through by setting:
  #use_proxies: true

#raft:
#  data_dir: .
#  self_addr: 127.0.0.1:2222
#  partner_addrs:
#  - 127.0.0.1:2223
#  - 127.0.0.1:2224
# The bootstrap configuration. Works only when the cluster is not yet initialized.
# If the cluster is already initialized, all changes in the `bootstrap` section are ignored!
bootstrap:
  # This section will be written into Etcd:/<namespace>/<scope>/config after initializing new cluster
  # and all other cluster members will use it as a `global configuration`.
  # WARNING! If you want to change any of the parameters that were set up
  # via `bootstrap.dcs` section, please use `patronictl edit-config`!
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
#    primary_start_timeout: 300
#    synchronous_mode: false
    #standby_cluster:
      #host: 127.0.0.1
      #port: 1111
      #primary_slot_name: patroni
    postgresql:
      use_pg_rewind: true
      pg_hba:
      # For kerberos gss based connectivity (discard @.*$)
      #- host replication replicator 127.0.0.1/32 gss include_realm=0
      #- host all all 0.0.0.0/0 gss include_realm=0
      - host replication replicator 127.0.0.1/32 md5
      - host replication replicator 10.10.10.32/0 md5
      - host replication replicator 10.10.10.9/0 md5
      - host replication replicator 10.10.10.17/0 md5
      - host all all 0.0.0.0/0 md5
       #  - hostssl all all 0.0.0.0/0 md5
#      use_slots: true
      parameters:
#        wal_level: hot_standby
#        hot_standby: "on"
#        max_connections: 100
#        max_worker_processes: 8
#        wal_keep_segments: 8
#        max_wal_senders: 10
#        max_replication_slots: 10
#        max_prepared_transactions: 0
#        max_locks_per_transaction: 64
#        wal_log_hints: "on"
#        track_commit_timestamp: "off"
#        archive_mode: "on"
#        archive_timeout: 1800s
#        archive_command: mkdir -p ../wal_archive && test ! -f ../wal_archive/%f && cp %p ../wal_archive/%f
#      recovery_conf:
#        restore_command: cp ../wal_archive/%f %p
# some desired options for 'initdb'
  initdb:  # Note: It needs to be a list (some options need values, others are switches)
  - encoding: UTF8
  - data-checksums

  # Additional script to be launched after initial cluster creation (will be passed the connection URL as parameter)
# post_init: /usr/local/bin/setup_cluster.sh

postgresql:
  listen: 10.10.10.9:5432
  connect_address: 10.10.10.9:5432

#  proxy_address: 127.0.0.1:5433  # The address of connection pool (e.g., pgbouncer) running next to Patroni/Postgres. Only for service discovery.
  data_dir: /var/lib/pgsql/16/data
  bin_dir: /usr/pgsql-16/bin/
#  config_dir:
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: rep-pass
    superuser:
      username: postgres
      password: patroni
    rewind:  # Has no effect on postgres 10 and lower
      username: rewind_user
      password: rewind_password
        # Server side kerberos spn
#  krbsrvname: postgres
  parameters:
    # Fully qualified kerberos ticket file for the running user
    # same as KRB5CCNAME used by the GSS
#   krb_server_keyfile: /var/spool/keytabs/postgres
    unix_socket_directories: '..'  # parent directory of data_dir
  # Additional fencing script executed after acquiring the leader lock but before promoting the replica
  #pre_promote: /path/to/pre_promote.sh

#watchdog:
#  mode: automatic # Allowed values: off, automatic, required
#  device: /dev/watchdog
#  safety_margin: 5

tags:
    # failover_priority: 1
    noloadbalance: false
    clonefrom: false
    nosync: false
    nostream: false
```

```
[root@db-02 ~]# patronictl -c /etc/patroni/patroni.yml list
+ Cluster: PgsqlCluster (7387450593716519572) ----+-----------+
| Member | Host        | Role    | State     | TL | Lag in MB |
+--------+-------------+---------+-----------+----+-----------+
| etcd1  | 10.10.10.17 | Replica | streaming |  1 |         0 |
| etcd2  | 10.10.10.9  | Replica | streaming |  1 |         0 |
| etcd3  | 10.10.10.32 | Leader  | running   |  1 |           |
+--------+-------------+---------+-----------+----+-----------+
```

> Как видим, мастером стал хост с IP адресом 10.10.10.16, то есть сервер db-03.

> Для проверки работы стенда воспользуемся отображением простой страницы собственноручно созданного сайта на PHP, имитирующий продажу новых и подержанных
> автомобилей: