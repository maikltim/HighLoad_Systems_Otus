# hashicorp vault

## веб портал с централизованным хранилищем секретов в nomad

## Цель: развернуть кластер веб приложения через nomad; там же развернуть vault кластер и реализовать обновления паролей к БД через каждые 2 минуты.

> https://github.com/erlong15/otus-vault/blob/main/k8s-materials/04-Vault/00-Homework.md

## Выполнение домашнего задания

> Стенд будем разворачивать с помощью Terraform на YandexCloud, настройку серверов будем выполнять с помощью Kubernetes.


> Kubernetes кластер будем разворачивать с помощью Terraform, а все установки и настройки необходимых приложений будем реализовывать с помощью команд
> kubectl и helm.

> Установка kubectl с помощью встроенного пакетного менеджера:

```
# This overwrites any existing configuration in /etc/yum.repos.d/kubernetes.repo
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
sudo dnf install -y kubectl
```

> Установка helm:

```
curl -LO https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz
tar -xf ./helm-v3.13.3-linux-amd64.tar.gz
sudo mv ./linux-amd64/helm /usr/local/bin/
rm -rf ./helm-v3.13.3-linux-amd64.tar.gz ./linux-amd64/
```

> Для того чтобы развернуть kubernetes кластер, нужно выполнить следующую команду:

```
terraform init && terraform apply -auto-approve
```

## Hashicorp Vault + K8s

### Что с нами будет?
- Ветка для работы: kubernetes-vault
- В ходе работы мы:
    - установим кластер vault в kubernetes
    - научимся создавать секреты и политики
    - настроим авторизацию в vault через kubernetes sa
    - сделаем под с контейнером nginx, в который прокинем секреты из vault через consul-template

# Подготовка
- должен быть запущенный kubernetes кластер
- Все созданные в процесс ДЗ файлы должны быть в репозитории
- вспомогательные ссылки
    - vault
    - vault-guides 

- лейбл homework-11 
- юзернейм для assignee erlong15


### Инсталляция hashicorp vault HA в k8s

- склонируем репозиторий consul (необходимо минимум 3 ноды)
```
git clone https://github.com/hashicorp/consul-helm.git
```
    - Так как немного устарело, поэтому в файле ./consul-helm/templates/server-disruptionbudget.yaml подредактировал строку

```
apiVersion: policy/v1
```

```
helm install consul ./consul-helm
```

```
[user@rocky9 hw-13]$ helm install consul ./consul-helm
NAME: consul
LAST DEPLOYED: Tue Jan 16 20:26:31 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Consul!

Now that you have deployed Consul, you should look over the docs on using 
Consul with Kubernetes available here: 

https://www.consul.io/docs/platform/k8s/index.html


Your release is named consul.

To learn more about the release, run:

 $ helm status consul
 $ helm get all consul
[user@rocky9 hw-13]$ 
```

```
git clone https://github.com/hashicorp/vault-helm.git
```

### Отредактируем параметры установки в values.yaml

```
  standalone:
   enabled: false
 ...
 ha:
   enabled: true
 ...
   config: |
     ui = true

     listener "tcp" {
       tls_disable = 1
       address = "[::]:8200"
       cluster_address = "[::]:8201"
     }
     storage "consul" {
       path = "vault"
       #address = "HOST_IP:8500"             # <--- закоментировал
       address = "consul-consul-server:8500" # <--- добавил правильную строку
     }
 ...
ui:
 enabled: true
 serviceType: "ClusterIP"
```

> Установим vault

```
helm install vault ./vault-helm/
helm status vault
kubectl logs vault-0
```

- обратите внимание на статус подов vault
- вывод helm status vault - добавьте в README.md

```
[user@rocky9 hw-13]$ helm status vault
NAME: vault
LAST DEPLOYED: Tue Sep 24 20:27:35 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://developer.hashicorp.com/vault/docs


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
[user@rocky9 hw-13]$ 
```

```
[user@rocky9 hw-13]$ kubectl logs vault-0
==> Vault server configuration:

Administrative Namespace: 
             Api Address: http://10.112.128.8:8200
                     Cgo: disabled
         Cluster Address: https://vault-0.vault-internal:8201
   Environment Variables: CONSUL_CONSUL_DNS_PORT, CONSUL_CONSUL_DNS_PORT_53_TCP, CONSUL_CONSUL_DNS_PORT_53_TCP_ADDR, CONSUL_CONSUL_DNS_PORT_53_TCP_PORT, ...
              Go Version: go1.21.3
              Listener 1: tcp (addr: "[::]:8200", cluster address: "[::]:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
               Log Level: 
                   Mlock: supported: true, enabled: false
           Recovery Mode: false
                 Storage: consul (HA available)
                 Version: Vault v1.15.2, built 2023-11-06T11:33:28Z
             Version Sha: cf1b5cafa047bc8e4a3f93444fcb4011593b92cb

==> Vault server started! Log data will stream in below:


2024-09-24T17:27:56.501Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2024-09-24T17:27:56.501Z [WARN]  storage.consul: appending trailing forward slash to path
2024-09-24T17:27:56.509Z [INFO]  incrementing seal generation: generation=1
2024-09-24T17:27:56.510Z [INFO]  core: Initializing version history cache for core
2024-09-24T17:27:56.510Z [INFO]  events: Starting event system
2024-09-24T17:28:02.958Z [INFO]  core: security barrier not initialized
2024-09-24T17:28:02.958Z [INFO]  core: seal configuration missing, not initialized
2024-09-24T17:28:07.947Z [INFO]  core: security barrier not initialized
2024-09-24T17:28:07.948Z [INFO]  core: seal configuration missing, not initialized
2024-09-24T17:28:12.965Z [INFO]  core: security barrier not initialized
2024-09-24T17:28:12.965Z [INFO]  core: seal configuration missing, not initialized
2024-09-24T17:28:17.947Z [INFO]  core: security barrier not initialized
2024-09-24T17:28:17.947Z [INFO]  core: seal configuration missing, not initialized
2024-09-24T17:28:22.952Z [INFO]  core: security barrier not initialized
2024-09-24T17:28:22.952Z [INFO]  core: seal configuration missing, not initialized
2024-09-24T17:28:27.941Z [INFO]  core: security barrier not initialized
2024-09-24T17:28:27.941Z [INFO]  core: seal configuration missing, not initialized
[user@rocky9 hw-13]$ 
```

## Инициализируем vault

- проведите инициализацию через любой под vault'а

```
kubectl exec -it vault-0 -- vault operator init --key-shares=5 --key-threshold=3
```


```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault operator init --key-shares=5 --key-threshold=3
Unseal Key 1: Xsy7G2fZwNuNtxQHXx90gS1T8fL0uLVwRGUCUhWxfrjm
Unseal Key 2: tXZ8gWHyb/5tLBJrLmORzuyZIenqWMIMQQrDMkWKdEls
Unseal Key 3: qPfsHBSp/qZ5fJqyD3tjxu6Ahtllk40eX/9hMg2B2vda
Unseal Key 4: tUx9STgP1Q/JzPE5xeapE7hbLf8mQVssuEopW122N8+8
Unseal Key 5: tvZiBvbIv7XG0bdtcPuRxHvb2aqtQcUan2Nswa0JyUQa



Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
[user@rocky9 hw-13]$ 
```

> сохраните ключи, полученные при инициализации

```
Unseal Key 1: Xsy7G2fZwNuNtxQHXx90gS1T8fL0uLVwRGUCUhWxfrjm
Unseal Key 2: tXZ8gWHyb/5tLBJrLmORzuyZIenqWMIMQQrDMkWKdEls
Unseal Key 3: qPfsHBSp/qZ5fJqyD3tjxu6Ahtllk40eX/9hMg2B2vda
Unseal Key 4: tUx9STgP1Q/JzPE5xeapE7hbLf8mQVssuEopW122N8+8
Unseal Key 5: tvZiBvbIv7XG0bdtcPuRxHvb2aqtQcUan2Nswa0JyUQa


```

## Проверим состояние vault'а

```
kubectl logs vault-0
```

```
[user@rocky9 hw-13]$ kubectl logs vault-0
==> Vault server configuration:

Administrative Namespace: 
             Api Address: http://10.112.128.8:8200
                     Cgo: disabled
         Cluster Address: https://vault-0.vault-internal:8201
   Environment Variables: CONSUL_CONSUL_DNS_PORT, CONSUL_CONSUL_DNS_PORT_53_TCP, CONSUL_CONSUL_DNS_PORT_53_TCP_ADDR, CONSUL_CONSUL_DNS_PORT_53_TCP_PORT, ...
              Go Version: go1.21.3
              Listener 1: tcp (addr: "[::]:8200", cluster address: "[::]:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
               Log Level: 
                   Mlock: supported: true, enabled: false
           Recovery Mode: false
                 Storage: consul (HA available)
                 Version: Vault v1.15.2, built 2023-11-06T11:33:28Z
             Version Sha: cf1b5cafa047bc8e4a3f93444fcb4011593b92cb

==> Vault server started! Log data will stream in below:

2024-09-24T17:27:56.501Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2024-09-24T17:27:56.501Z [WARN]  storage.consul: appending trailing forward slash to path
2024-09-24T17:27:56.509Z [INFO]  incrementing seal generation: generation=1
2024-09-24T17:27:56.510Z [INFO]  core: Initializing version history cache for core
2024-09-24T17:27:56.510Z [INFO]  events: Starting event system
2024-09-24T17:28:02.958Z [INFO]  core: security barrier not initialized
2024-09-24T17:28:02.958Z [INFO]  core: seal configuration missing, not initialized
2024-09-24T17:28:07.947Z [INFO]  core: security barrier not initialized
2024-09-24T17:28:07.948Z [INFO]  core: seal configuration missing, not initialized
...
2024-09-24T17:46:39.704Z [INFO]  core: security barrier not initialized
2024-09-24T17:46:39.704Z [INFO]  core: seal configuration missing, not initialized
2024-09-24T17:46:39.705Z [INFO]  core: security barrier not initialized
2024-09-24T17:46:39.748Z [INFO]  core: security barrier initialized: stored=1 shares=5 threshold=3
2024-09-24T17:46:39.835Z [INFO]  core: post-unseal setup starting
2024-09-24T17:46:39.850Z [INFO]  core: loaded wrapping token key
2024-09-24T17:46:39.850Z [INFO]  core: successfully setup plugin runtime catalog
2024-09-24T17:46:39.850Z [INFO]  core: successfully setup plugin catalog: plugin-directory=""
2024-09-24T17:46:39.851Z [INFO]  core: no mounts; adding default mount table
2024-09-24T17:46:39.872Z [INFO]  core: successfully mounted: type=cubbyhole version="v1.15.2+builtin.vault" path=cubbyhole/ namespace="ID: root. Path: "
2024-09-24T17:46:39.872Z [INFO]  core: successfully mounted: type=system version="v1.15.2+builtin.vault" path=sys/ namespace="ID: root. Path: "
2024-09-24T17:46:39.873Z [INFO]  core: successfully mounted: type=identity version="v1.15.2+builtin.vault" path=identity/ namespace="ID: root. Path: "
2024-09-24T17:46:39.970Z [INFO]  core: successfully mounted: type=token version="v1.15.2+builtin.vault" path=token/ namespace="ID: root. Path: "
2024-09-24T17:46:40.039Z [INFO]  rollback: Starting the rollback manager with 256 workers
2024-09-24T17:46:40.040Z [INFO]  rollback: starting rollback manager
2024-09-24T17:46:40.040Z [INFO]  core: restoring leases
2024-09-24T17:46:40.041Z [INFO]  expiration: lease restore complete
2024-09-24T17:46:40.068Z [INFO]  identity: entities restored
2024-09-24T17:46:40.068Z [INFO]  identity: groups restored
2024-09-24T17:46:40.070Z [INFO]  core: usage gauge collection is disabled
2024-09-24T17:46:40.080Z [INFO]  core: Recorded vault version: vault version=1.15.2 upgrade time="2024-09-24 17:46:40.069974673 +0000 UTC" build date=2023-11-06T11:33:28Z
2024-09-24T17:46:40.659Z [INFO]  core: post-unseal setup complete
2024-09-24T17:46:40.713Z [INFO]  core: root token generated
2024-09-24T17:46:40.713Z [INFO]  core: pre-seal teardown starting
2024-09-24T17:46:40.713Z [INFO]  rollback: stopping rollback manager
2024-09-24T17:46:40.713Z [INFO]  core: pre-seal teardown complete
[user@rocky9 hw-13]$ 
```

> Обратите внимание на параметры Initialized, Sealed

```
kubectl exec -it vault-0 -- vault status
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.2.2
HA Enabled         true
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault status
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    0/3
Unseal Nonce       n/a
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
command terminated with exit code 2
[user@rocky9 hw-13]$ 
```

## Распечатаем vault

- Обратите внимание на переменные окружения в подах

```
 kubectl exec -it vault-0 -- env | grep VAULT
 VAULT_ADDR=http://127.0.0.1:8200
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- env | grep VAULT
VAULT_K8S_POD_NAME=vault-0
VAULT_CLUSTER_ADDR=https://vault-0.vault-internal:8201
VAULT_API_ADDR=http://10.112.128.8:8200
VAULT_K8S_NAMESPACE=default
VAULT_ADDR=http://127.0.0.1:8200
VAULT_ACTIVE_PORT_8201_TCP_PORT=8201
VAULT_STANDBY_PORT=tcp://10.96.131.169:8200
VAULT_STANDBY_PORT_8200_TCP_PROTO=tcp
VAULT_SERVICE_HOST=10.96.137.143
VAULT_UI_PORT=tcp://10.96.214.88:8200
VAULT_ACTIVE_PORT_8200_TCP=tcp://10.96.252.96:8200
VAULT_STANDBY_PORT_8201_TCP_PROTO=tcp
VAULT_SERVICE_PORT=8200
VAULT_STANDBY_SERVICE_PORT_HTTP=8200
VAULT_PORT_8200_TCP_PORT=8200
VAULT_PORT_8201_TCP_PROTO=tcp
VAULT_PORT_8201_TCP_PORT=8201
VAULT_AGENT_INJECTOR_SVC_SERVICE_PORT=443
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP_ADDR=10.96.189.21
VAULT_ACTIVE_SERVICE_PORT=8200
VAULT_PORT=tcp://10.96.137.143:8200
VAULT_ACTIVE_SERVICE_HOST=10.96.252.96
VAULT_SERVICE_PORT_HTTP=8200
VAULT_STANDBY_PORT_8201_TCP=tcp://10.96.131.169:8201
VAULT_AGENT_INJECTOR_SVC_PORT=tcp://10.96.189.21:443
VAULT_ACTIVE_PORT_8201_TCP=tcp://10.96.252.96:8201
VAULT_UI_SERVICE_PORT=8200
VAULT_ACTIVE_PORT=tcp://10.96.252.96:8200
VAULT_ACTIVE_PORT_8201_TCP_PROTO=tcp
VAULT_SERVICE_PORT_HTTPS_INTERNAL=8201
VAULT_UI_PORT_8200_TCP_PROTO=tcp
VAULT_AGENT_INJECTOR_SVC_SERVICE_PORT_HTTPS=443
VAULT_ACTIVE_PORT_8200_TCP_ADDR=10.96.252.96
VAULT_UI_PORT_8200_TCP_ADDR=10.96.214.88
VAULT_ACTIVE_SERVICE_PORT_HTTP=8200
VAULT_STANDBY_SERVICE_PORT_HTTPS_INTERNAL=8201
VAULT_STANDBY_PORT_8200_TCP_ADDR=10.96.131.169
VAULT_PORT_8201_TCP=tcp://10.96.137.143:8201
VAULT_PORT_8201_TCP_ADDR=10.96.137.143
VAULT_ACTIVE_PORT_8200_TCP_PROTO=tcp
VAULT_ACTIVE_PORT_8201_TCP_ADDR=10.96.252.96
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP=tcp://10.96.189.21:443
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP_PROTO=tcp
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP_PORT=443
VAULT_ACTIVE_SERVICE_PORT_HTTPS_INTERNAL=8201
VAULT_ACTIVE_PORT_8200_TCP_PORT=8200
VAULT_UI_SERVICE_HOST=10.96.214.88
VAULT_STANDBY_PORT_8201_TCP_ADDR=10.96.131.169
VAULT_STANDBY_PORT_8200_TCP=tcp://10.96.131.169:8200
VAULT_STANDBY_PORT_8201_TCP_PORT=8201
VAULT_PORT_8200_TCP=tcp://10.96.137.143:8200
VAULT_UI_SERVICE_PORT_HTTP=8200
VAULT_STANDBY_SERVICE_HOST=10.96.131.169
VAULT_PORT_8200_TCP_PROTO=tcp
VAULT_UI_PORT_8200_TCP_PORT=8200
VAULT_STANDBY_SERVICE_PORT=8200
VAULT_UI_PORT_8200_TCP=tcp://10.96.214.88:8200
VAULT_STANDBY_PORT_8200_TCP_PORT=8200
VAULT_PORT_8200_TCP_ADDR=10.96.137.143
VAULT_AGENT_INJECTOR_SVC_SERVICE_HOST=10.96.189.21
[user@rocky9 hw-13]$ 
```

- Распечатать нужно каждый под


```
kubectl exec -it vault-0 -- vault operator unseal 'qpt7e1w2D2tQqPdknR8A5VFrzFZ0Yz6W/BPoFMX5x2A='
kubectl exec -it vault-1 -- vault operator unseal 'qpt7e1w2D2tQqPdknR8A5VFrzFZ0Yz6W/BPoFMX5x2A='
kubectl exec -it vault-2 -- vault operator unseal 'qpt7e1w2D2tQqPdknR8A5VFrzFZ0Yz6W/BPoFMX5x2A='
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault operator unseal 'Xsy7G2fZwNuNtxQHXx90gS1T8fL0uLVwRGUCUhWxfrjm'
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    1/3
Unseal Nonce       b4d29b83-78e8-5778-ccdd-cab8feeb4811
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault operator unseal 'tXZ8gWHyb/5tLBJrLmORzuyZIenqWMIMQQrDMkWKdEls'
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    2/3
Unseal Nonce       b4d29b83-78e8-5778-ccdd-cab8feeb4811
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault operator unseal 'qPfsHBSp/qZ5fJqyD3tjxu6Ahtllk40eX/9hMg2B2vda'
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    5
Threshold       3
Version         1.15.2
Build Date      2023-11-06T11:33:28Z
Storage Type    consul
Cluster Name    vault-cluster-b19dcecc
Cluster ID      b45344c6-3506-be6d-b88b-b326660cf3d0
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
Active Since    2024-09-24T17:54:46.44054218Z
[user@rocky9 hw-13]$ 
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-2 -- vault operator unseal 'Xsy7G2fZwNuNtxQHXx90gS1T8fL0uLVwRGUCUhWxfrjm'
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    1/3
Unseal Nonce       c3446bb0-4333-6351-9943-fad69b88a732
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
[user@rocky9 hw-13]$ kubectl exec -it vault-2 -- vault operator unseal 'tXZ8gWHyb/5tLBJrLmORzuyZIenqWMIMQQrDMkWKdEls'
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    2/3
Unseal Nonce       c3446bb0-4333-6351-9943-fad69b88a732
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       consul
HA Enabled         true
[user@rocky9 -13]$ kubectl exec -it vault-2 -- vault operator unseal 'qPfsHBSp/qZ5fJqyD3tjxu6Ahtllk40eX/9hMg2B2vda'
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           5
Threshold              3
Version                1.15.2
Build Date             2023-11-06T11:33:28Z
Storage Type           consul
Cluster Name           vault-cluster-b19dcecc
Cluster ID             b45344c6-3506-be6d-b88b-b326660cf3d0
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.112.128.8:8200
[user@rocky9 hw-13]$ 
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault status
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    5
Threshold       3
Version         1.15.2
Build Date      2023-11-06T11:33:28Z
Storage Type    consul
Cluster Name    vault-cluster-b19dcecc
Cluster ID      b45344c6-3506-be6d-b88b-b326660cf3d0
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
Active Since    2024-09-24T17:54:46.44054218Z
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-1 -- vault status
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           5
Threshold              3
Version                1.15.2
Build Date             2023-11-06T11:33:28Z
Storage Type           consul
Cluster Name           vault-cluster-b19dcecc
Cluster ID             b45344c6-3506-be6d-b88b-b326660cf3d0
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.112.128.8:8200
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-2 -- vault status
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           5
Threshold              3
Version                1.15.2
Build Date             2023-11-06T11:33:28Z
Storage Type           consul
Cluster Name           vault-cluster-b19dcecc
Cluster ID             b45344c6-3506-be6d-b88b-b326660cf3d0
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.112.128.8:8200
[user@rocky9 hw-13]$ 
```

## Посмотрим список доступных авторизаций

- выполните

```
kubectl exec -it vault-0 -- vault auth list
```

- получите ошибку

```
Error listing enabled authentications: Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/auth
Code: 400. Errors:

* missing client token
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault auth list
Error listing enabled authentications: Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/auth
Code: 403. Errors:

* permission denied
command terminated with exit code 2
[user@rocky9 hw-13]$ 
```

## Залогинимся в vault (у нас есть root token)

```
kubectl exec -it vault-0 -- vault login

Token (will be hidden):
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----

token_accessor       awM0XRV1aIYmDzVFpC0U5BP9
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
[user@rocky9 hw-13]$ 
```

```
kubectl exec -it vault-0 -- vault auth list
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault auth list
Path      Type     Accessor               Description                Version
----      ----     --------               -----------                -------
token/    token    auth_token_3cdd5f14    token based credentials    n/a
[user@rocky9 hw-13]$ 
```

## Заведем секреты

```
kubectl exec -it vault-0 -- vault secrets enable --version=2 --path=otus kv
kubectl exec -it vault-0 -- vault secrets list --detailed
kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus' password='h7sgm4j9ztp'
kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='h7sgm4j9ztp'
kubectl exec -it vault-0 -- vault read otus/otus-ro/config
kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault secrets enable --version=2 --path=otus kv
Success! Enabled the kv secrets engine at: otus/
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault secrets list --detailed
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options    Description                                                UUID                                    Version    Running Version          Running SHA256    Deprecation Status
----          ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------    -----------                                                ----                                    -------    ---------------          --------------    ------------------
cubbyhole/    cubbyhole    cubbyhole_0d0e5080    n/a            n/a        false             local          false        false                      map[]      per-token private secret storage                           86d82095-8fcf-4351-1ef6-f39490eaaec6    n/a        v1.15.2+builtin.vault    n/a               n/a
identity/     identity     identity_3de25df9     system         system     false             replicated     false        false                      map[]      identity store                                             f3c222c7-c508-9770-1469-a5ee0d912b94    n/a        v1.15.2+builtin.vault    n/a               n/a
otus/         kv           kv_6c46427d           system         system     false             replicated     false        false                      map[]      n/a                                                        b9139d6e-d6e6-c06a-37a2-06fa88abfff5    n/a        v0.16.1+builtin          n/a               supported
sys/          system       system_eed4f82b       n/a            n/a        false             replicated     true         false                      map[]      system endpoints used for control, policy and debugging    3a50dec2-c0bc-a9f7-61ca-8eae814b9bd7    n/a        v1.15.2+builtin.vault    n/a               n/a
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus' password='h7sgm4j9ztp'
Success! Data written to: otus/otus-ro/config
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='h7sgm4j9ztp'
Success! Data written to: otus/otus-rw/config
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault read otus/otus-ro/config
Key                 Value
---                 -----
refresh_interval    768h
password            h7sgm4j9ztp
username            otus
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
====== Data ======
Key         Value
---         -----
password    h7sgm4j9ztp
username    otus
[user@rocky9 hw-13]$ 
```

## Включим авторизацию через k8s

```
kubectl exec -it vault-0 -- vault auth enable kubernetes
kubectl exec -it vault-0 -- vault auth list
```

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault auth enable kubernetes
Success! Enabled kubernetes auth method at: kubernetes/
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault auth list
Path           Type          Accessor                    Description                Version
----           ----          --------                    -----------                -------
kubernetes/    kubernetes    auth_kubernetes_5c8e911f    n/a                        n/a
token/         token         auth_token_3cdd5f14         token based credentials    n/a
[user@rocky9 hw-13]$ 
```

## Создадим yaml для ClusterRoleBinding

- vault-auth-service-account.yml

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault-auth
    namespace: default
EOF
```

```
[user@rocky9 hw-13]$ vi vault-auth-service-account.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault-auth
    namespace: default
```

## Создадим Service Account vault-auth и применим ClusterRoleBinding


```
# Update the 'vault-auth' service account
$ kubectl apply -f ./vault-auth-service-account.yml
```

```
[user@rocky9 hw-13-13]$ kubectl apply -f ./vault-auth-service-account.yml 
clusterrolebinding.rbac.authorization.k8s.io/role-tokenreview-binding created
[user@rocky9 hw-13]$ 
```

## Создадим секрет vault-auth-secret

```
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-secret
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
```

```
kubectl apply -f ./vault-auth-secret.yaml
```

```
[user@rocky9 hw-13]$ vi ./vault-auth-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-secret
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
```

```
[user@rocky9 hw-13]$ kubectl apply -f ./vault-auth-secret.yaml
secret/vault-auth-secret created
[user@rocky9 hw-13]$ 
```

## Подготовим переменные для записи в конфиг кубер авторизации

```
export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
* alternative: export VAULT_SA_NAME=$(kubectl get secrets --output=json \
    | jq -r '.items[].metadata | select(.name|startswith("vault-auth-")).name')

export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
export K8S_HOST=$(more ~/.kube/config | grep server |awk '/http/ {print $NF}')

### alternative way
export K8S_HOST=$(kubectl cluster-info | grep 'Kubernetes control plane' | awk '/https/ {print $NF}' | sed 's/\x1b\[[0-9;]*m//g' )
```

```
[user@rocky9 hw-13]$ export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ export K8S_HOST=$(more ~/.kube/config | grep server |awk '/http/ {print $NF}')
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ export K8S_HOST=$(kubectl cluster-info | grep 'Kubernetes control plane' | awk '/https/ {print $NF}' | sed 's/\x1b\[[0-9;]*m//g' )
[user@rocky9 hw-13]$ 
```

## Запишем конфиг в vault

```
kubectl exec -it vault-0 -- vault write auth/kubernetes/config \
token_reviewer_jwt="$SA_JWT_TOKEN" \
kubernetes_host="$K8S_HOST" \
kubernetes_ca_cert="$SA_CA_CRT"
```
## Создадим файл политики

```
tee otus-policy.hcl <<EOF
path "otus/data/otus-ro/*" {
  capabilities = ["read", "list"]
}

path "otus/data/otus-rw/*" {
  capabilities = ["read", "create", "list"]
}
EOF
```

```
[user@rocky9 hw-13]$ tee otus-policy.hcl <<EOF
path "otus/data/otus-ro/*" {
  capabilities = ["read", "list"]
}

path "otus/data/otus-rw/*" {
  capabilities = ["read", "create", "list"]
}
EOF
path "otus/data/otus-ro/*" {
  capabilities = ["read", "list"]
}

path "otus/data/otus-rw/*" {
  capabilities = ["read", "create", "list"]
}
[user@rocky9 hw-13]$ 
```

## создадим политику и роль в vault

```
kubectl cp otus-policy.hcl vault-0:/tmp/

kubectl exec -it vault-0 -- vault policy write otus-policy /tmp/otus-policy.hcl

kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus  \
bound_service_account_names=vault-auth         \
bound_service_account_namespaces=default policies=otus-policy  ttl=24h
```

## Проверим как работает авторизация
 
 - Создадим под с привязанным сервис аккоунтом и установим туда curl и jq

```
kubectl run --generator=run-pod/v1 tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7
apk add curl jq

If you don't see a command prompt, try pressing enter.
/ # 
/ # apk add curl jq
fetch http://dl-cdn.alpinelinux.org/alpine/v3.7/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.7/community/x86_64/APKINDEX.tar.gz
(1/6) Installing ca-certificates (20190108-r0)
(2/6) Installing libssh2 (1.9.0-r1)
(3/6) Installing libcurl (7.61.1-r3)
(4/6) Installing curl (7.61.1-r3)
(5/6) Installing oniguruma (6.6.1-r0)
(6/6) Installing jq (1.5-r5)
Executing busybox-1.27.2-r11.trigger
Executing ca-certificates-20190108-r0.trigger
OK: 7 MiB in 19 packages
/ # 
```

- Залогинимся и получим клиентский токен

```
VAULT_ADDR=http://vault:8200
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --request POST  --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
TOKEN=$(curl -k -s --request POST  --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')

 % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0{
  "request_id": "e83b7a8a-8d0c-7bf5-76cb-2f8e1c4929af",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": null,
  "wrap_info": null,
  "warnings": null,
  "auth": {
   
    "accessor": "o3UQ0ZVhlAGEm6aYY6q4FpDm",
    "policies": [
      "default",
      "otus-policy"
    ],
    "token_policies": [
      "default",
      "otus-policy"
    ],
    "metadata": {
      "role": "otus",
      "service_account_name": "vault-auth",
      "service_account_namespace": "default",
      "service_account_secret_name": "",
      "service_account_uid": "f1d7e441-c410-41cb-ac9f-51dc6085536a"
    },
    "lease_duration": 86400,
    "renewable": true,
    "entity_id": "e215fb49-f409-1bda-f409-e587a95c625d",
    "token_type": "service",
    "orphan": true,
    "mfa_requirement": null,
    "num_uses": 0
  }
}
100  1714  100   749  100   965   7271   9368 --:--:-- --:--:-- --:--:-- 16640
/ # 
/ # TOKEN=$(curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')
/ # 
```

## Прочитаем записанные ранее секреты и попробуем их обновить

```
/ # curl --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config
{"request_id":"4216cba9-8d22-098b-1f61-9fcf8ad2cd3c","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"h7sgm4j9ztp","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
/ # 
/ # curl --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
{"request_id":"52d8847f-3cfa-4b40-04bd-48f08fe275f5","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"h7sgm4j9ztp","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
/ # 
```

- проверим запись

```
/ # curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
/ # 
/ # curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
/ # 
/ # curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config1
/ # 
```

## Разберемся с ошибками при записи

> Мы смогли записать otus-rw/config1, но не смогли otus-rw/config, так как в политике роли otus/data/otus-rw 'read', 'create', 'list'. Для того чтобы была
> возможность записать otus-rw/config, добавим в политику 'update'.

> В новом терминале создадим новый файл otus-policy1.hcl и обновим политику в Vault:


```
[user@rocky9 hw-13]$ tee otus-policy1.hcl <<EOF
path "otus/data/otus-ro/*" {
  capabilities = ["read", "list"]
}

path "otus/data/otus-rw/*" {
  capabilities = ["read", "update", "create", "list"]
}
EOF
path "otus/data/otus-ro/*" {
  capabilities = ["read", "list"]
}

path "otus/data/otus-rw/*" {
  capabilities = ["read", "update", "create", "list"]
}
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl cp ./otus-policy1.hcl vault-0:/tmp/
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault policy write otus-policy /tmp/otus-policy1.hcl
Success! Uploaded policy: otus-policy
[user@rocky9 hw-13]$ 
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus  \
bound_service_account_names=vault-auth         \
bound_service_account_namespaces=default policies=otus-policy  ttl=24h
Success! Data written to: auth/kubernetes/role/otus
[user@rocky9 hw-13]$ 
```

## Снова проверим запись otus-rw/config в поде tmp:

```
/ # curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
/ # 
```

> Как видим, запись прошла без ошибок.

## Use case использования авторизации через кубер

- Авторизуемся через vault-agent и получим клиентский токен
- Через consul-template достанем секрет и положим его в nginx
- Итог - nginx получил секрет из волта, не зная ничего про волт


## Заберем репозиторий с примерами

```
git clone https://github.com/hashicorp/vault-guides.git
cd ./vault-guides/identity/vault-agent-k8s-demo
```

- В каталоге configs-k8s скорректируйте конфиги с учетом ранее созданых ролей и секретов
- Проверьте и скорректируйте конфиг example-k8s-spec.yml
- Скорректированные конфиги приложить к ДЗ

> В файлах configmap.yaml и example-k8s-spec.yaml вносим изменения с учетом того, чтобы контейнер nginx-container каждые две миинуты запрашивал данные с
> кластера vault, в частности, username и password для последующего отображения на странице браузера для демонстрации:

```
[user@rocky9 vault-agent-k8s-demo]$ cat ./configmap.yaml 
apiVersion: v1
data:
  vault-agent-config.hcl: |
    # Comment this out if running as sidecar instead of initContainer
    exit_after_auth = true

    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "otus"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }

    template {
    destination = "/etc/secrets/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "otus/data/otus-rw/config" }}
    <ul>
    <li><pre>username: {{ .Data.data.username }}</pre></li>
    <li><pre>password: {{ .Data.data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }

    vault {
        address = "http://vault:8200"
    }

  vault-agent-rendered.hcl: |
    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "otus"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }

    template {
    destination = "/etc/secrets/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "otus/data/otus-rw/config" }}
    <ul>
    <li><pre>username: {{ .Data.data.username }}</pre></li>
    <li><pre>password: {{ .Data.data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }

    template_config {
        static_secret_render_interval = "2m"
    }

    vault {
        address = "http://vault:8200"
    }
kind: ConfigMap
metadata:
  name: example-vault-agent-config
  namespace: default
[user@rocky9 vault-agent-k8s-demo]$ 
```
```
[user@rocky9 vault-agent-k8s-demo]$ cat ./example-k8s-spec.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: vault-agent-example
  namespace: default
spec:
  serviceAccountName: vault-auth

  volumes:
  - configMap:
      items:
      - key: vault-agent-config.hcl
        path: vault-agent-config.hcl
      - key: vault-agent-rendered.hcl
        path: vault-agent-rendered.hcl
      name: example-vault-agent-config
    name: config
  - emptyDir:
      medium: Memory
    name: shared-data

  initContainers:
  - args:
    - agent
    - -config=/etc/vault/vault-agent-config.hcl
    - -log-level=debug
    env:
    - name: VAULT_ADDR
      value: http://vault:8200
    image: hashicorp/vault:latest
    name: vault-agent
    volumeMounts:
    - mountPath: /etc/vault
      name: config
    - mountPath: /etc/secrets
      name: shared-data

  containers:
  - image: nginx:latest
    name: nginx-container
    ports:
    - containerPort: 80
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: shared-data
#    resources:
#      requests:
#        memory: 256Mi
#        cpu: "0.2"
#      limits:
#        memory: 512Mi
#        cpu: "0.4"
  - image: hashicorp/vault:latest
    name: vault-agent-remdered
    args:
    - agent
    - -config=/etc/vault/vault-agent-rendered.hcl
    - -log-level=debug
    env:
    - name: VAULT_ADDR
      value: http://vault:8200
    volumeMounts:
    - mountPath: /etc/vault
      name: config
    - mountPath: /etc/secrets
      name: shared-data
[user@rocky9 vault-agent-k8s-demo]$ 
```

## Запускаем пример

```
# Create a ConfigMap, example-vault-agent-config
$ kubectl create -f configmap.yaml

# View the created ConfigMap
$ kubectl get configmap example-vault-agent-config -o yaml

# Finally, create vault-agent-example Pod
$ kubectl apply -f example-k8s-spec.yaml

[user@rocky9 vault-agent-k8s-demo]$ kubectl create -f configmap.yaml
configmap/example-vault-agent-config created
[user@rocky9 vault-agent-k8s-demo]$ 



[user@rocky9 vault-agent-k8s-demo]$ kubectl get configmap example-vault-agent-config -o yaml
apiVersion: v1
data:
  vault-agent-config.hcl: |
    # Comment this out if running as sidecar instead of initContainer
    exit_after_auth = true

    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "otus"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }

    template {
    destination = "/etc/secrets/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "otus/data/otus-rw/config" }}
    <ul>
    <li><pre>username: {{ .Data.data.username }}</pre></li>
    <li><pre>password: {{ .Data.data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }

    vault {
        address = "http://vault:8200"
    }
  vault-agent-rendered.hcl: |
    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "otus"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }

    template {
    destination = "/etc/secrets/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "otus/data/otus-rw/config" }}
    <ul>
    <li><pre>username: {{ .Data.data.username }}</pre></li>
    <li><pre>password: {{ .Data.data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }

    template_config {
        static_secret_render_interval = "2m"
    }

    vault {
        address = "http://vault:8200"
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2024-09-24T20:32:00Z"
  name: example-vault-agent-config
  namespace: default
  resourceVersion: "146737"
  uid: db276814-84eb-4346-a8d1-11868809e205
[user@rocky9 vault-agent-k8s-demo]$ 
```

```
[user@rocky9 vault-agent-k8s-demo]$ kubectl apply -f ./example-k8s-spec.yaml
pod/vault-agent-example created
[user@rocky9 vault-agent-k8s-demo]$ 
```

## Проверка

- законнектится к поду nginx и вытащить оттуда index.html
- index.html приложить к ДЗ

```
[user@rocky9 vault-agent-k8s-demo]$ kubectl cp --container nginx-container vault-agent-example:/usr/share/nginx/html/index.html ./index.html
tar: Removing leading `/' from member names
[user@rocky9 vault-agent-k8s-demo]$ 
```

> Содержимое файла index.html:


```
[user@rocky9 vault-agent-k8s-demo]$ cat ./index.html 
<html>
<body>
<p>Some secrets:</p>
<ul>
<li><pre>username: otus</pre></li>
<li><pre>password: h7sgm4j9ztp</pre></li>
</ul>

</body>
</html>
[user@rocky9 vault-agent-k8s-demo]$ 
```

> Пробросим порт 8080 на порт 80 контейнера nginx-container в поде vault-agent-example:

> и введя в строке браузера:

```
http://localhost:8080
```

> увидим следующую веб-страницу:

![alt text](images/1.png)

> Так как в конфиге настроено, что данные веб-страницы меняются через каждые две минуты, для проверки поменяем пароль:

```
[user@rocky9 vault-agent-k8s-demo]$ kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='vault@Otus1234'
====== Secret Path ======
otus/data/otus-rw/config

======= Metadata =======
Key                Value
---                -----
created_time       2024-09-24T20:21:37.797155457Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            2
[user@rocky9 vault-agent-k8s-demo]$ 
```

> Обновляя веб-страницу в веб-браузере в течение двух минут должно обновиться значение пароля:

![alt text](images/2.png)

## создадим CA на базе vault

- Включим pki секретс
```
 kubectl exec -it vault-0 -- vault secrets enable pki
 kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
 kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal  \
 common_name="exmaple.ru"  ttl=87600h > CA_cert.crt

 [user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault secrets enable pki
Success! Enabled the pki secrets engine at: pki/
[user@rocky9 hw-13]$ 

[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
Success! Tuned the secrets engine at: pki/
[user@rocky9 hw-13]$ 

[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal  \
 common_name="exmaple.ru"  ttl=87600h > CA_cert.crt
[user@rocky9 hw-13]$ 
```

## пропишем урлы для ca и отозванных сертификатов

```
 kubectl exec -it vault-0 -- vault write pki/config/urls  \
 issuing_certificates="http://vault:8200/v1/pki/ca"       \
 crl_distribution_points="http://vault:8200/v1/pki/crl"

 [user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write pki/config/urls  \
 issuing_certificates="http://vault:8200/v1/pki/ca"       \
 crl_distribution_points="http://vault:8200/v1/pki/crl"
Key                        Value
---                        -----
crl_distribution_points    [http://vault:8200/v1/pki/crl]
enable_templating          false
issuing_certificates       [http://vault:8200/v1/pki/ca]
ocsp_servers               []
[user@rocky9 hw-13]$ 
```

## создадим промежуточный сертификат


```
kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
kubectl exec -it vault-0 -- vault write -format=json pki_int/intermediate/generate/internal  \
common_name="example.ru Intermediate Authority"         | jq -r '.data.csr' > pki_intermediate.csr

[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
Success! Enabled the pki secrets engine at: pki_int/
[user@rocky9 hw-13]$ 

[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
Success! Tuned the secrets engine at: pki_int/
[user@rocky9 hw-13]$ 

[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write -format=json pki_int/intermediate/generate/internal  \
common_name="example.ru Intermediate Authority"         | jq -r '.data.csr' > pki_intermediate.csr
[user@rocky9 hw-13]$ 
```

## пропишем промежуточный сертификат в vault


```
kubectl cp pki_intermediate.csr vault-0:/home/vault
kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate \
csr=@"/home/vault/pki_intermediate.csr"   \      
format=pem_bundle ttl="43800h" |  jq -r '.data.certificate' > intermediate.cert.pem
kubectl cp intermediate.cert.pem vault-0:/home/vault
kubectl exec -it vault-0 -- vault write pki_int/intermediate/set-signed certificate=@"/home/vault/intermediate.cert.pem"
```

```
[user@rocky9 hw-13]$ kubectl cp pki_intermediate.csr vault-0:/home/vault
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate \
csr=@"/home/vault/pki_intermediate.csr"   \      
format=pem_bundle ttl="43800h" |  jq -r '.data.certificate' > intermediate.cert.pem
[user@rocky9 hw-13]$ 

[user@rocky9 hw-13]$ kubectl cp intermediate.cert.pem vault-0:/home/vault
[user@rocky9 hw-13]$ 

[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write pki_int/intermediate/set-signed certificate=@"/home/vault/intermediate.cert.pem"
WARNING! The following warnings were returned from Vault:

  * This mount hasn't configured any authority information access (AIA)
  fields; this may make it harder for systems to find missing certificates
  in the chain or to validate revocation status of certificates. Consider
  updating /config/urls or the newly generated issuer with this information.

Key                 Value
---                 -----
existing_issuers    <nil>
existing_keys       <nil>
imported_issuers    [d4646a47-0044-dcbf-0939-4ae9550a48cc 8b22ff96-5157-86a2-0cf8-7bd6f92242d5]
imported_keys       <nil>
mapping             map[8b22ff96-5157-86a2-0cf8-7bd6f92242d5: d4646a47-0044-dcbf-0939-4ae9550a48cc:ab3b88a4-4c8f-eeaa-dbd8-e781e3d5db25]
[user@rocky9 hw-13]$ 
```

## Создадим и отзовем новые сертификаты


- Создадим роль для выдачи сертификатов

```
kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru allowed_domains="example.ru" allow_subdomains=true max_ttl="720h"

[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru allowed_domains="example.ru" allow_subdomains=true max_ttl="720h"
Key                                   Value
---                                   -----
allow_any_name                        false
allow_bare_domains                    false
allow_glob_domains                    false
allow_ip_sans                         true
allow_localhost                       true
allow_subdomains                      true
allow_token_displayname               false
allow_wildcard_certificates           true
allowed_domains                       [example.ru]
allowed_domains_template              false
allowed_other_sans                    []
allowed_serial_numbers                []
allowed_uri_sans                      []
allowed_uri_sans_template             false
allowed_user_ids                      []
basic_constraints_valid_for_non_ca    false
client_flag                           true
cn_validations                        [email hostname]
code_signing_flag                     false
country                               []
email_protection_flag                 false
enforce_hostnames                     true
ext_key_usage                         []
ext_key_usage_oids                    []
generate_lease                        false
issuer_ref                            default
key_bits                              2048
key_type                              rsa
key_usage                             [DigitalSignature KeyAgreement KeyEncipherment]
locality                              []
max_ttl                               720h
no_store                              false
not_after                             n/a
not_before_duration                   30s
organization                          []
ou                                    []
policy_identifiers                    []
postal_code                           []
province                              []
require_cn                            true
server_flag                           true
signature_bits                        256
street_address                        []
ttl                                   0s
use_csr_common_name                   true
use_csr_sans                          true
use_pss                               false
[user@rocky9 hw-13]$ 
```
- Создадим и отзовем сертификат:

```
kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru common_name="www.example.ru" ttl="24h"
kubectl exec -it vault-0 -- vault write pki_int/revoke serial_number="04:70:d4:7e:c5:d3:ec:ec:a0:5d:cf:20:6f:e8:f8:81:f2:8e:99:6b"
```

> Создадим сертификат:


```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru common_name="www.example.ru" ttl="24h"
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUeq9DSuqw7HZ4EfHrnoO4en+XUdUwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjEwNzA5NDNaFw0yOTAx
MTkwNzEwMTNaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOMKHvZx30EM
iFAzb8aLzqsRtIRmVn6zsY+FuRfQ36Sv1jvTjwLuh4evhZOCoO5mW1gJBUdCIpg5
uMa4ekiauTQ4OAplrJgcQvqYRrzPqmU3jjf5e9lJVTSkddQ91z0wqYsChTiMdfqM
ByCo8cxaiTUcdckHnNtPGjanEq1ZzyCmBom9GXKvpeE/x5NGoHw+i+xiGpjOZnDj
7c18enT7moj8emiY+NL/gZZkpXkGgmycc5SkSYU0JrhPWtu4VbziAlfO7igGCi71
kMEEpN//bfnfKNqqfYTiJbURNMSHHgzD/KSA3ey9g/DwFXY31VMu3f6/uywAf7If
Ngq/VPMfE5UCAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUcvW6aNOeUXFkmEjxv04Mnf45w1gwHwYDVR0jBBgwFoAU
+H8ZJx2CSpvN3veSHa/BLYRMBbUwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
YxaZ9xKacu9DNb8L+9EOmtaaiFT95a9JigSm4AmvL70uPkKxafqsZodOiZUTt7E9
NtaJKVBracJw0avj4+rV7m0qpNWrMDU57MYKU5If4lv1EqoKenVagbPbH+98rLuI
45H8XrwG0EVDS9OrCmB690WjOIRZiTvWqyVy+VNf39cvOwLVmO4z9E7Yk3TLBN2q
0q3PKKmtxouaz6kYZ5Tndkd5HEdkDBjwKWOHPGNbMDM7AseJpF8+/aFXzwfIT0r1
EefTBP4yQ+KETKWz5lGVZRiefuv9uzHgdDPTc80A1Kv0ROsbkwpQu4iEzcMCHQMA
otbpyHHn7puuUBS9Ztg7FQ==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIUCFwY9M7hw4AXjm17NgqMuf8eRTswDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjEwNjM3MjZaFw0zNDAx
MTgwNjM3NTZaMBUxEzARBgNVBAMTCmV4bWFwbGUucnUwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQC9FUsh2Zu0Y/CKXJiL3Do9upYYk1/Hdn0fwqBJVtgc
SOiPogaFZ8dMNKxKQ1kx70BB6+1kaTNCqtT5BjNbjJZsZzm2+DGOcZkaAtL2fPTk
1fnanzQ3YGYbGeQs7M4sEA2J68qHvwn8o6w4krqulc89z62kmIcd6cSuUSNbXp1T
TIppO5L1+yMUZUv0NkhAMSuk+2CVdyuoWjNp7t9vgsuYKs7azd0DuVz+18UK+E/N
74DM/pFbmBSlwwEncP3zBER2eLAPAbkTz2bhcuxxptt+6NyqslldUZidNBhUwfCX
kn4WLAXUjO44pqX0WCR8g5TGMC9aUPH8BUwGmkrP09u1AgMBAAGjejB4MA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBT4fxknHYJKm83e
95Idr8EthEwFtTAfBgNVHSMEGDAWgBT4fxknHYJKm83e95Idr8EthEwFtTAVBgNV
HREEDjAMggpleG1hcGxlLnJ1MA0GCSqGSIb3DQEBCwUAA4IBAQCGmPi9lAvaEoIA
N4P7mds1FilCuMNVRYc0FdJdj8P6ezc+TM/Ku0Iu2dASL2QNfOhZZ45fKVgNUM+e
YmCipenwMy2Ky004jeIe4sfIRxl9kt2LWgHv2cZst/d8om5yfnujVy7DrX2KkT9J
9JOSNewBZ25vXrRTB9V7DtWZ+tkYt3DDrVSO9q1IyvHgGkOWvU86Ogxkyi8kHQHa
hv65mQF5aTw5MPrVfzxsAm5tDLEEvkO0v2lRhODLyIvNRWFUBhT6h6TnyYp2kG+N
eHAlbNIK50OZjUohcX18FW8dLzmfbT4g8wVU06VNW5GWLa9hNg4/s2mvk3BPv/ms
cbYnHP9y
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDYTCCAkmgAwIBAgIUBHDUfsXT7OygXc8gb+j4gfKOmWswDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTI0MDEyMTA3MzAyNloXDTI0MDEyMjA3MzA1NlowGTEXMBUGA1UEAxMOd3d3
LmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDKT0nF
maOTk/PuGHWnBqSIAvA+pBU4s9B9Sm9Ej7bbYr2+FlmNzXCjcqsjJbOqvQLedG4V
zifXhN2uwhZm0RrlIuv2Dqn/OjcNcJKKvsTDxghZl9xQTGCYBFF4VRKF7HBJjIlw
DovisfhnBSsNcPK/M0zeEV1bBg/ErfFjOiCyNgsieb3/kCHa4ATbMCseu/YI4gCL
KokvyAmiSkT0ggJqvJgB+KBUAphmRY2jh27mJQFyAJi/Yzc/5aKxXzvkcuMRC1KK
6s+o3sXpx+WfxTREvji1PDdzQPvnJKR/WkG/edt7gZgqiWHoGb1ysZ4sqMmxktPt
1fJhY8zjH+tjbuXnAgMBAAGjgY0wgYowDgYDVR0PAQH/BAQDAgOoMB0GA1UdJQQW
MBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUAFaxxaQ8ijntl2tfAFgB
NJ7l8sAwHwYDVR0jBBgwFoAUcvW6aNOeUXFkmEjxv04Mnf45w1gwGQYDVR0RBBIw
EIIOd3d3LmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBAD7FJOtjL5szQH08
Yfwb/y6yuiLPBO0PxSmZYF+opyRhuGvGtYokxTPG8naSKtKfjOjhLUH+naoAw4aF
E4HLKyY8P3LJ+M1rX0YCsdOrzftUmE3mnA2phq9cbgdmrfYuKwAA2N2qjRDlPJUQ
zER2kmWpFSTgaEADbuc1V3T5U3AS+/jm7gBgCKUpTaHBRzbG5CF09KroqWPgv8LT
gMPWCeUzrWxQas/c7DoiRqeIXGZxOmhhUMoBgmRIaB+8EuzeC78/kOtr8kaqwtbD
L/rV0QAOAPnHO12jpYQ9TgFKn5s1MglTsMTv2L8UaCMDT3hxSAqO6guZQud6bZMc
1nHhSjw=
-----END CERTIFICATE-----
expiration          1705908656
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUeq9DSuqw7HZ4EfHrnoO4en+XUdUwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yNDAxMjEwNzA5NDNaFw0yOTAx
MTkwNzEwMTNaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOMKHvZx30EM
iFAzb8aLzqsRtIRmVn6zsY+FuRfQ36Sv1jvTjwLuh4evhZOCoO5mW1gJBUdCIpg5
uMa4ekiauTQ4OAplrJgcQvqYRrzPqmU3jjf5e9lJVTSkddQ91z0wqYsChTiMdfqM
ByCo8cxaiTUcdckHnNtPGjanEq1ZzyCmBom9GXKvpeE/x5NGoHw+i+xiGpjOZnDj
7c18enT7moj8emiY+NL/gZZkpXkGgmycc5SkSYU0JrhPWtu4VbziAlfO7igGCi71
kMEEpN//bfnfKNqqfYTiJbURNMSHHgzD/KSA3ey9g/DwFXY31VMu3f6/uywAf7If
Ngq/VPMfE5UCAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUcvW6aNOeUXFkmEjxv04Mnf45w1gwHwYDVR0jBBgwFoAU
+H8ZJx2CSpvN3veSHa/BLYRMBbUwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
YxaZ9xKacu9DNb8L+9EOmtaaiFT95a9JigSm4AmvL70uPkKxafqsZodOiZUTt7E9
NtaJKVBracJw0avj4+rV7m0qpNWrMDU57MYKU5If4lv1EqoKenVagbPbH+98rLuI
45H8XrwG0EVDS9OrCmB690WjOIRZiTvWqyVy+VNf39cvOwLVmO4z9E7Yk3TLBN2q
0q3PKKmtxouaz6kYZ5Tndkd5HEdkDBjwKWOHPGNbMDM7AseJpF8+/aFXzwfIT0r1
EefTBP4yQ+KETKWz5lGVZRiefuv9uzHgdDPTc80A1Kv0ROsbkwpQu4iEzcMCHQMA
otbpyHHn7puuUBS9Ztg7FQ==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAyk9JxZmjk5Pz7hh1pwakiALwPqQVOLPQfUpvRI+222K9vhZZ
jc1wo3KrIyWzqr0C3nRuFc4n14TdrsIWZtEa5SLr9g6p/zo3DXCSir7Ew8YIWZfc
UExgmARReFUShexwSYyJcA6L4rH4ZwUrDXDyvzNM3hFdWwYPxK3xYzogsjYLInm9
/5Ah2uAE2zArHrv2COIAiyqJL8gJokpE9IICaryYAfigVAKYZkWNo4du5iUBcgCY
v2M3P+WisV875HLjEQtSiurPqN7F6cfln8U0RL44tTw3c0D75ySkf1pBv3nbe4GY
Kolh6Bm9crGeLKjJsZLT7dXyYWPM4x/rY27l5wIDAQABAoIBAH+L+XCw6mYSc0l6
9kH1eCmf4KM9g3uaMimrkfbhvGEYIZQENzWlfgwuMSMZk+pi+7oQIY9xx8CirbiN
+N2dm502pRkeKaMVqru4a0s59oePBJinm2isnoF4x3xb9i+k3y4fgk65fQvRNFCO
+5Of0AsnZqDixb6rVamkGHl8njx7oxhI3B3HorTVpVog4/gTUBcDyZo3HorBV3E/
ka0FR8SkyU6pgetkwjqfBleNnTnxWiHTsbtHp/visKcOPQ7RUYF5E8k+5pV92TUg
yC114fV7uus7gHBLWf64ShLHM1e2H8br5jtSbMjvtiNNqCjr9JWxlq14QKzM1UPa
DgCnB+ECgYEA49qF6KlMkZQRolI95vKFflFvSlrePYJE7MJYQ5xMW5150TMZL5Pu
ENNbb7KqQig2hex7/eMLBCXLm4e7w8z8ZS6loh/OVfA5N3mS2b4JeRPhynPKxNKz
JYknjV78RiwMpB2yijT9329PHN4p95v0bns9RPODcT5w4GACeqQ6htkCgYEA40z7
2Sl7XEDbIoIqpdzitg6jBeeHj3YMM2yMMHqaXcpYaazwdogaS0edZN4Kj4sr7rUa
aS0nkRiGFIjs1vGKvN3PBetJYk+ZgeElKiDeXp3PjaAc82pRIPCeJxSP9SnqJwpE
GW0iFJlBMly4DlE7ycXqaulT14MywMo/Xqm8Wr8CgYAlNTQU0ECurS1MAn4VTpk6
DXZNABW2maVDvGDJeaaGd2rDHMMKH/AKU1llHhnrf8GXkQyWYxMTdFCRb1LcIIc+
xqVJmkQJiJbvVi0C3aOSYArJEquUBIw4nvMUhORRWTQfQLI9G3YxnG2g2y6jPpZl
zD4vGkzmmzm3ijYdbOAZ0QKBgQCMocDgp42vkmEChM6mOHf8dCnhKVLyK/N4jZxf
EjwX822oVFuiuqqqEPEMy2R1U4Im+t4QXOOyHh427lC63E8ec43295A7x0wO06IO
4q8ykykrUvkWkZ0IaFcxjsNSyFAbP3rK0H7Zh8iSxFMMaK45NL7IzvwUxxPLvFZg
11u2OQKBgQCCLAeGJCBhVbpHfQPTMD9h5BhO4oXzAX6gkWjf04vbGGpQ3HBztg+u
Da4T+6TWaDY3ZHJEcE0kBYnNftZL0cHFH0F4EX+F9iM1gv2oz/yGHxTiLS5D5uql
8ArVJsi6xQShDxEMtGvZlyCXfdDVDAkCT8CinSR5FLwkMe0nhrmwZA==
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       04:70:d4:7e:c5:d3:ec:ec:a0:5d:cf:20:6f:e8:f8:81:f2:8e:99:6b
[user@rocky9 hw-13]$ 
```

> Отзываем сертификат:

```
[user@rocky9 hw-13]$ kubectl exec -it vault-0 -- vault write pki_int/revoke serial_number="04:70:d4:7e:c5:d3:ec:ec:a0:5d:cf:20:6f:e8:f8:81:f2:8e:99:6b"
Key                        Value
---                        -----
revocation_time            1705851871
revocation_time_rfc3339    2024-09-24T15:44:31.904503534Z
state                      revoked
[user@rocky9 hw-13]$ 
```

> Установка Vault Helm chart

> Vault управляет секретами, которые записываются на эти подключаемые тома. Для предоставления этих секретов требуется отдельный сервер Vault. Для этой
> демонстрации Vault можно запустить в режиме разработки, чтобы автоматически выполнить инициализацию, распечатку и настройку движка KV secrets engine.

1. Добавим репозиторий HashiCorp Helm:

```
helm repo add hashicorp https://helm.releases.hashicorp.com

[user@rocky9 hw-13]$ helm repo add hashicorp https://helm.releases.hashicorp.com
"hashicorp" has been added to your repositories
[user@rocky9 hw-13]$ 
```

2. Обновим все репозитории, чтобы убедиться, что helm определяет последние версии:

```
helm repo update

[user@rocky9 hw-13]$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "hashicorp" chart repository
Update Complete. ⎈Happy Helming!⎈
[user@rocky9 hw-13]$ 
```

3. Для проверки выполним поиск репо vault:

```
helm search repo hashicorp/vault

[user@rocky9 hw-13]$ helm search repo hashicorp/vault
NAME                            	CHART VERSION	APP VERSION	DESCRIPTION                          
hashicorp/vault                 	0.27.0       	1.15.2     	Official HashiCorp Vault Chart       
hashicorp/vault-secrets-operator	0.4.3        	0.4.3      	Official Vault Secrets Operator Chart
[user@rocky9 hw-13]$ 
```

## Создание сертификата

1. Создадим временно рабочий директорий:

```
mkdir /tmp/vault
```

2. Экспортируем расположение рабочего каталога и переменные:

```
export VAULT_K8S_NAMESPACE="vault" \
export VAULT_HELM_RELEASE_NAME="vault" \
export VAULT_SERVICE_NAME="vault-internal" \
export K8S_CLUSTER_NAME="cluster.local" \
export WORKDIR=/tmp/vault
```

3. Сгенерируем закрытый ключ:

```
openssl genrsa -out ${WORKDIR}/vault.key 2048

[user@rocky9 hw-13]$ openssl genrsa -out ${WORKDIR}/vault.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
....................................................+++++
.+++++
e is 65537 (0x010001)
[user@rocky9 hw-13]$ 
```

## Создание запроса на подписание сертификата (CSR)

1. Создадим файл конфигурации CSR:

```
cat > ${WORKDIR}/vault-csr.conf <<EOF
[req]
default_bits = 2048
prompt = no
encrypt_key = yes
default_md = sha256
distinguished_name = kubelet_serving
req_extensions = v3_req
[ kubelet_serving ]
O = system:nodes
CN = system:node:*.${VAULT_K8S_NAMESPACE}.svc.${K8S_CLUSTER_NAME}
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.${VAULT_SERVICE_NAME}
DNS.2 = *.${VAULT_SERVICE_NAME}.${VAULT_K8S_NAMESPACE}.svc.${K8S_CLUSTER_NAME}
DNS.3 = *.${VAULT_K8S_NAMESPACE}
IP.1 = 127.0.0.1
EOF
```

```
[user@rocky9 hw-13]$ cat > ${WORKDIR}/vault-csr.conf <<EOF
[req]
default_bits = 2048
prompt = no
encrypt_key = yes
default_md = sha256
distinguished_name = kubelet_serving
req_extensions = v3_req
[ kubelet_serving ]
O = system:nodes
CN = system:node:*.${VAULT_K8S_NAMESPACE}.svc.${K8S_CLUSTER_NAME}
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.${VAULT_SERVICE_NAME}
DNS.2 = *.${VAULT_SERVICE_NAME}.${VAULT_K8S_NAMESPACE}.svc.${K8S_CLUSTER_NAME}
DNS.3 = *.${VAULT_K8S_NAMESPACE}
IP.1 = 127.0.0.1
EOF
[user@rocky9 hw-13]$ 
```

2. Создадим CSR:

```
openssl req -new -key ${WORKDIR}/vault.key -out ${WORKDIR}/vault.csr -config ${WORKDIR}/vault-csr.conf

[user@rocky9 hw-13]$ openssl req -new -key ${WORKDIR}/vault.key -out ${WORKDIR}/vault.csr -config ${WORKDIR}/vault-csr.conf
[user@rocky9 hw-13]$ 

```

## Создание сертификата

1. Создадим csr yaml файл для отправки в Kubernetes:

```
cat > ${WORKDIR}/csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
   name: vault.svc
spec:
   signerName: kubernetes.io/kubelet-serving
   expirationSeconds: 8640000
   request: $(cat ${WORKDIR}/vault.csr|base64|tr -d '\n')
   usages:
   - digital signature
   - key encipherment
   - server auth
EOF
```


```
[user@rocky9 hw-13]$ cat > ${WORKDIR}/csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
   name: vault.svc
spec:
   signerName: kubernetes.io/kubelet-serving
   expirationSeconds: 8640000
   request: $(cat ${WORKDIR}/vault.csr|base64|tr -d '\n')
   usages:
   - digital signature
   - key encipherment
   - server auth
EOF
[user@rocky9 hw-13]$ 
```

2. Отправим CSR в Kubernetes:

```
kubectl create -f ${WORKDIR}/csr.yaml

[user@rocky9 hw-13]$ kubectl create -f ${WORKDIR}/csr.yaml
certificatesigningrequest.certificates.k8s.io/vault.svc created
[user@rocky9 hw-13]$ 
```

3. Утвердим CSR в Kubernetes:

```
[user@rocky9 hw-13]$ kubectl certificate approve vault.svc
certificatesigningrequest.certificates.k8s.io/vault.svc approved
[user@rocky9 hw-13]$ 
```

4. Подтвердим выдачу сертификата:

```
[user@rocky9 hw-13]$ kubectl get csr vault.svc
NAME        AGE    SIGNERNAME                      REQUESTOR              REQUESTEDDURATION   CONDITION
vault.svc   4m9s   kubernetes.io/kubelet-serving   ajecd4tsnko7s5au92sj   100d                Approved,Issued
[user@rocky9 hw-13]$ 
```

## Хранение сертификатов и ключей в хранилище секретов Kubernetes

1. Получим сертификат:

```
[user@rocky9 hw-13]$ kubectl get csr vault.svc -o jsonpath='{.status.certificate}' | openssl base64 -d -A -out ${WORKDIR}/vault.crt
[user@rocky9 hw-13]$ 
```

2. Получим сертификат центра сертификации Kubernetes:

```
[user@rocky9 hw-13]$ kubectl config view \
--raw \
--minify \
--flatten \
-o jsonpath='{.clusters[].cluster.certificate-authority-data}' \
| base64 -d > ${WORKDIR}/vault.ca
[user@rocky9 hw-13]$ 
```

3. Создадим пространство имен Kubernetes 'vault':


```
[user@rocky9 hw-13]$ kubectl create namespace $VAULT_K8S_NAMESPACE
namespace/vault created
[user@rocky9 hw-13]$ 
```

4. Создадим TLS секрет:

```
[user@rocky9 hw-13]$ kubectl create secret generic vault-ha-tls \
   -n $VAULT_K8S_NAMESPACE \
   --from-file=vault.key=${WORKDIR}/vault.key \
   --from-file=vault.crt=${WORKDIR}/vault.crt \
   --from-file=vault.ca=${WORKDIR}/vault.ca
secret/vault-ha-tls created
[user@rocky9 hw-13]$ 
```

## Развертывание кластера vault через helm с переопределениями

1. Создадим файл overrides.yaml:


```
cat > ${WORKDIR}/overrides.yaml <<EOF
global:
   enabled: true
   tlsDisable: false
injector:
   enabled: true
server:
   extraEnvironmentVars:
      VAULT_CACERT: /vault/userconfig/vault-ha-tls/vault.ca
      VAULT_TLSCERT: /vault/userconfig/vault-ha-tls/vault.crt
      VAULT_TLSKEY: /vault/userconfig/vault-ha-tls/vault.key
   volumes:
      - name: userconfig-vault-ha-tls
        secret:
         defaultMode: 420
         secretName: vault-ha-tls
   volumeMounts:
      - mountPath: /vault/userconfig/vault-ha-tls
        name: userconfig-vault-ha-tls
        readOnly: true
   standalone:
      enabled: false
   affinity: ""
   ha:
      enabled: true
      replicas: 3
      raft:
         enabled: true
         setNodeId: true
         config: |
            ui = true
            listener "tcp" {
               tls_disable = 0
               address = "[::]:8200"
               cluster_address = "[::]:8201"
               tls_cert_file = "/vault/userconfig/vault-ha-tls/vault.crt"
               tls_key_file  = "/vault/userconfig/vault-ha-tls/vault.key"
               tls_client_ca_file = "/vault/userconfig/vault-ha-tls/vault.ca"
            }
            storage "raft" {
               path = "/vault/data"
            }
            disable_mlock = true
            service_registration "kubernetes" {}
EOF
```

2. Разворачиваем кластер 'vault' в пространстве имён 'vault':

```
[user@rocky9 hw-13]$ helm install -n $VAULT_K8S_NAMESPACE $VAULT_HELM_RELEASE_NAME hashicorp/vault -f ${WORKDIR}/overrides.yaml
NAME: vault
LAST DEPLOYED: Mon Jan 22 10:10:43 2024
NAMESPACE: vault
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://developer.hashicorp.com/vault/docs


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
[user@rocky9 hw-13]$ 
```

3. Отобразим поды в пространстве имен, созданном для 'vault':

```
[user@rocky9 hw-13]$ kubectl -n $VAULT_K8S_NAMESPACE get pods
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 0/1     Running   0          113s
vault-1                                 0/1     Running   0          113s
vault-2                                 0/1     Running   0          113s
vault-agent-injector-78b768864b-fq5rw   1/1     Running   0          113s
[user@rocky9 hw-13]$ 
```

4. Инициализируем vault-0 с помощью одного общего ключа и одного порогового значения ключа (в демонстрационных целях):


```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > ${WORKDIR}/cluster-keys.json
[user@rocky9 hw-13]$ 
```

> operator init: команда генерирует корневой ключ, который разбирается на общие ключи -key-shares=1, а затем устанавливает количество общих ключей, 
> необходимых для разблокировки Vault -key-threshold=1. Эти общие ключи записываются в выходные данные в виде ключей распечатки в формате JSON 
> -format=json. Здесь выходные данные перенаправляются в файл с именем cluster-keys.json.

5. Отобразим ключ разблокировки, найденный в cluster-keys.json:

```
[user@rocky9 hw-13]$ jq -r ".unseal_keys_b64[]" ${WORKDIR}/cluster-keys.json
PfyFSeyJU7NsfY+H5ACXjP1vxMrdjm5rSp4n4lw2bng=
[user@rocky9 hw-13]$ 
```

> После инициализации Vault настроен так, чтобы знать, где и как получить доступ к хранилищу, но не знает, как расшифровать что-либо из этого. Снятие 
> печати - это процесс создания корневого ключа, необходимого для считывания ключа дешифрования для расшифровки данных, обеспечивающего доступ к Хранилищу.

7. Распечатаем Vault, запущенный на vault-0 модуле:

```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            1
Threshold               1
Version                 1.15.2
Build Date              2023-11-06T11:33:28Z
Storage Type            raft
Cluster Name            vault-cluster-6930a56a
Cluster ID              3ae6672d-a2b0-8eec-9e10-e0f12aefd1e1
HA Enabled              true
HA Cluster              https://vault-0.vault-internal:8201
HA Mode                 active
Active Since            2024-09-24T07:28:21.853806523Z
Raft Committed Index    53
Raft Applied Index      53
[user@rocky9 hw-13]$ 
```

> Сервер Vault инициализирован и распечатан.

> Внимание! Небезопасная операция!

> Предоставление ключа распечатки с помощью команды записывает ключ в историю вашей оболочки. Этот подход используется здесь только для упрощения процесса
> распечатки для этой демонстрации.


> Команда operator unseal сообщает, что хранилище инициализировано и распечатано.

## Присоединение к кластеру Raft подов vault-1 и vault2

1. Запустим сеанс интерактивной командной строки в поде vault-1:

```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE -it vault-1 -- /bin/sh
/ $ 
```

> Наше системное приглашение заменено новым / $

2. Присоединим под vault-1 к кластеру Raft:

```
/ $ vault operator raft join -address=https://vault-1.vault-internal:8200 -leade
r-ca-cert="$(cat /vault/userconfig/vault-ha-tls/vault.ca)" -leader-client-cert="
$(cat /vault/userconfig/vault-ha-tls/vault.crt)" -leader-client-key="$(cat /vaul
t/userconfig/vault-ha-tls/vault.key)" https://vault-0.vault-internal:8200
Key       Value
---       -----
Joined    true
/ $ 
```

3. Выходим из пода vault-1:

```
/ $ exit
```

4. Распечатаем vault-1:


```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE -ti vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       raft
HA Enabled         true
[user@rocky9 hw-13]$ 
```

5. Запустим сеанс интерактивной командной строки в поде vault-2:

```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE -it vault-2 -- /bin/sh
/ $ 
```

> Наше системное приглашение заменено новым / $.

6. Присоединим под vault-2 к кластеру Raft:

```
/ $ vault operator raft join -address=https://vault-2.vault-internal:8200 -leade
r-ca-cert="$(cat /vault/userconfig/vault-ha-tls/vault.ca)" -leader-client-cert="
$(cat /vault/userconfig/vault-ha-tls/vault.crt)" -leader-client-key="$(cat /vaul
t/userconfig/vault-ha-tls/vault.key)" https://vault-0.vault-internal:8200
Key       Value
---       -----
Joined    true
/ $ 
```

7. Выходим из пода vault-2:

```
/ $ exit
[user@rocky9 hw-13]$ 
```

8. Распечатаем vault-2.

```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE -ti vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.15.2
Build Date         2023-11-06T11:33:28Z
Storage Type       raft
HA Enabled         true
[user@rocky9 hw-13]$ 
```
> Войдём в vault и убедимся, что все работает

9. Экспортируем корневой токен кластера:

```
[user@rocky9 hw-13]$ export CLUSTER_ROOT_TOKEN=$(cat ${WORKDIR}/cluster-keys.json | jq -r ".root_token")
[user@rocky9 hw-13]$ 
```

10. Войдём в vault-0 с помощью токена root:

```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- vault login $CLUSTER_ROOT_TOKEN
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token_accessor       vQnuExeqIUnzRrqxaD3E1j50
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
[user@rocky9 hw-13]$ 
```

11. Список узлов raft:

```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- vault operator raft list-peers
Node       Address                        State       Voter
----       -------                        -----       -----
vault-0    vault-0.vault-internal:8201    leader      true
vault-1    vault-1.vault-internal:8201    follower    true
vault-2    vault-2.vault-internal:8201    follower    true
[user@rocky9 hw-13]$ 
```

12. Распечатаем статус HA:

```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- vault status
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            1
Threshold               1
Version                 1.15.2
Build Date              2023-11-06T11:33:28Z
Storage Type            raft
Cluster Name            vault-cluster-6930a56a
Cluster ID              3ae6672d-a2b0-8eec-9e10-e0f12aefd1e1
HA Enabled              true
HA Cluster              https://vault-0.vault-internal:8201
HA Mode                 active
Active Since            2024-09-24T07:28:21.853806523Z
Raft Committed Index    82
Raft Applied Index      82
[user@rocky9 hw-13]$ 
```

>Теперь у нас есть работающий кластер из 3 узлов с включенным TLS на уровне pod. Затем мы создадим секрет и получим его с помощью вызова API, чтобы
> подтвердить, что TLS работает должным образом.

## Создание секрета

1. Запустим сеанс интерактивной командной строки в поде vault-0:

```
[user@rocky9 hw-13]$ kubectl exec -n $VAULT_K8S_NAMESPACE -it vault-0 -- /bin/sh
/ $ 
```

> Наше системное приглашение заменено новым '/ $'.

2. Включим движок секретов kv-v2:

```

/ $ vault secrets enable -path=secret kv-v2
Success! Enabled the kv-v2 secrets engine at: secret/
/ $ 
```

3. Создадим секрет на пути secret/tls/apitest с помощью username и password:

```
/ $ vault kv put secret/tls/apitest username="apiuser" password="supersecret@Otu
s1234"
===== Secret Path =====
secret/data/tls/apitest

======= Metadata =======
Key                Value
---                -----
created_time       2024-09-24T07:53:40.634755447Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
/ $ 
```

4. Убедимся, что секрет указан в пути secret/tls/apitest:

```
/ $ vault kv get secret/tls/apitest
===== Secret Path =====
secret/data/tls/apitest

======= Metadata =======
Key                Value
---                -----
created_time       2024-09-24T07:53:40.634755447Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1

====== Data ======
Key         Value
---         -----
password    supersecret@Otus1234
username    apiuser
/ $ 
```

5. Выходим из пода vault-0:

```
/ $ exit
[user@rocky9 hw-13]$ 
```

## Создание сервиса и получение секрета через API

> В Helm-схеме определен сервис Kubernetes с именем vault, который пересылает запросы своим конечным точкам (т.е. подам с именами vault-0, vault-1 и 
> vault-2).

1. Конфигурация сервиса 'vault':

```
[user@rocky9 hw-13]$ kubectl -n $VAULT_K8S_NAMESPACE get service vault
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
vault   ClusterIP   10.96.172.198   <none>        8200/TCP,8201/TCP   51m
[user@rocky9 hw-13]$ 
```

2. В другом терминале пробросим порт 8200 сервиса 'vault':

```
[user@rocky9 hw-13]$ kubectl -n vault port-forward service/vault 8200:8200
Forwarding from 127.0.0.1:8200 -> 8200
```

3. В исходном терминале выполним HTTPS запрос curl для извлечения секрета, созданного нами ранее:

```
[user@rocky9 hw-13]$ curl --cacert $WORKDIR/vault.ca \
  --header "X-Vault-Token: $CLUSTER_ROOT_TOKEN" \
  https://127.0.0.1:8200/v1/secret/data/tls/apitest | jq .data.data
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   356  100   356    0     0   3128      0 --:--:-- --:--:-- --:--:--  3150
{
  "password": "supersecret@Otus1234",               # <--- получено значение 'password'
  "username": "apiuser"                             # <--- получено значение 'username'
}
[user@rocky9 hw-13]$ 
```

> Таким образом, мы получили секрет, созданный нами ранее.

## Удаление стенда

```
terraform destroy -auto-approve
```