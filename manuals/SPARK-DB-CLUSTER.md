# HA-Proxy

Source: https://technotim.live/posts/postgresql-high-availability/

### spark-db-proxy-01

```
CT ID: 2000
IP: 10.10.2.1/16
Gateway: 10.10.0.1
```

---

# DB Nodes

### spark-db-01

```
CT ID: 2010
IP: 10.10.2.10/16
Gateway: 10.10.0.1
```

### spark-db-02

```
CT ID: 2011
IP: 10.10.2.11/16
Gateway: 10.10.0.1
```

### spark-db-03

```
CT ID: 2012
IP: 10.10.2.12/16
Gateway: 10.10.0.1
```

---

# Installation

## PostgreSQL

Auf den Datenbank Nodes muss die neuste Version von Postgres installiert werden.

**Update installieren & postgres repositories hinzufügen:**

```shell
sudo apt update
sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
```

**Postgres und Module installieren:**

```shell
sudo apt update
sudo apt install -y postgresql postgresql-contrib
```

Postgres wird später konfiguration.

**Postgres Service stoppen und deaktivieren:**

```shell
sudo systemctl stop postgresql
sudo systemctl disable postgresql
```

## etcd

etcd muss auf jedem postgres server installiert werden.

##### Vorrausetzungen:

- curl
- wget

```shell
sudo apt update
sudo apt-get install -y wget curl
```

**Neuste Version finden und installieren:**

[https://github.com/etcd-io/etcd/releases](https://github.com/etcd-io/etcd/releases)

```shell
wget https://github.com/etcd-io/etcd/releases/download/v3.6.4/etcd-v3.6.4-linux-amd64.tar.gz
```

**Entpacken und umbenennen:**

```shell
tar xvf etcd-v3.6.4-linux-amd64.tar.gz
mv etcd-v3.6.4-linux-amd64 etcd
```

**Binaries in `/usr/local/bin` für später verschieben:**

```shell
sudo mv etcd/etcd* /usr/local/bin/
```

**`etcd` Version prüfen:**

```shell
etcd --version
```

Das ganze sollte wie folgt aussehen:

```log
etcd Version: 3.6.4
Git SHA: 507c0deß
Go Version: go1.22.9obs
Go OS/Arch: linux/amd64
```

```
etcdctl version
```

Hier sollte die Antwort wie folgt aussehen:

```log
etcdctl version: 3.6.4
API version: 3.6
```

**Einen Benutzer für den etcd service anlegen:**

```shell
sudo useradd --system --home /var/lib/etcd --shell /bin/false etcd
```

## etcd

**Ordner erstellen:**

```shell
sudo mkdir -p /etc/etcd
sudo mkdir -p /etc/etcd/ssl
```

### Zertifikate Vorrausetzungen

**`openssl` muss installiert sein (AUF DEM EIGENEN PC):**

```bash
winget install -e --id FireDaemon.OpenSSL
```

**Installation überprüfen:**

```shell
openssl version
```

Die Antwort sollte wie folgt aussehen:

```
OpenSSL 3.4.0 22 Oct 2024 (Library: OpenSSL 3.4.0 22 Oct 2024)
```

### Zertifikate:

```shell
md certs
cd certs
```

**CA erstellen:**

```shell
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=etcd-ca" -days 7300 -out ca.crt
```

Generiere für jeden Knoten ein Zertifikat. Beachte bitte die SANS. Ich verwende IP. Aktualisiere mit IP und DNS/Hostname.

**spark-db-01:**

```shell
# Generate a private key
openssl genrsa -out etcd-spark-db-01.key 2048

# Create temp file for config
@"
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[ req_distinguished_name ]
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
IP.1 = 10.10.2.10
IP.2 = 127.0.0.1
"@ | Out-File -FilePath temp.cnf -Encoding UTF8

# Create a csr
openssl req -new -key etcd-spark-db-01.key -out etcd-spark-db-01.csr -subj "/C=DE/ST=BW/L=Zell/O=Schnebel-IT/OU=IT/CN=etcd-spark-db-01" -config temp.cnf

# Sign the cert
openssl x509 -req -in etcd-spark-db-01.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd-spark-db-01.crt -days 7300 -sha256 -extensions v3_req -extfile temp.cnf

# Verify the cert and be sure you see Subject Name Alternative

openssl x509 -in etcd-spark-db-01.crt -text -noout | Select-String -Pattern "Subject Alternative Name" -Context 0,1

# Remove temp file

rm temp.cnf
```

**spark-db-02:**

```shell
# Generate a private key
openssl genrsa -out etcd-spark-db-02.key 2048

# Create temp file for config
@"
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[ req_distinguished_name ]
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
IP.1 = 10.10.2.11
IP.2 = 127.0.0.1
"@ | Out-File -FilePath temp.cnf -Encoding UTF8

# Create a csr
openssl req -new -key etcd-spark-db-02.key -out etcd-spark-db-02.csr -subj "/C=DE/ST=BW/L=Zell/O=Schnebel-IT/OU=IT/CN=etcd-spark-db-02" -config temp.cnf

# Sign the cert
openssl x509 -req -in etcd-spark-db-02.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd-spark-db-02.crt -days 7300 -sha256 -extensions v3_req -extfile temp.cnf

# Verify the cert and be sure you see Subject Name Alternative
openssl x509 -in etcd-spark-db-02.crt -text -noout | Select-String -Pattern "Subject Alternative Name" -Context 0,1

# Remove temp file
rm temp.cnf
```

**spark-db-03:**

```shell
# Generate a private key
openssl genrsa -out etcd-spark-db-03.key 2048

# Create temp file for config
@"
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[ req_distinguished_name ]
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
IP.1 = 10.10.2.12
IP.2 = 127.0.0.1
"@ | Out-File -FilePath temp.cnf -Encoding UTF8

# Create a csr
openssl req -new -key etcd-spark-db-03.key -out etcd-spark-db-03.csr -subj "/C=DE/ST=BW/L=Zell/O=Schnebel-IT/OU=IT/CN=etcd-spark-db-03" -config temp.cnf

#Sign the cert
openssl x509 -req -in etcd-spark-db-03.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd-spark-db-03.crt -days 7300 -sha256 -extensions v3_req -extfile temp.cnf

# Verify the cert and be sure you see Subject Name Alternative
openssl x509 -in etcd-spark-db-03.crt -text -noout | Select-String -Pattern "Subject Alternative Name" -Context 0,1

# Remove temp file
rm temp.cnf
```

**Liste alle Dateien auf:**

```shell
ls
```

Die Antwort sollte wie folgt aussehen:

```log
ca.crt
ca.key
ca.srl
etcd-node1.crt
etcd-node1.csr
etcd-node2.crt
etcd-node2.csr
etcd-node2.key
etcd-node3.crt
etcd-node3.csr
etcd-node3.key
```

**Kopiere die Zertifikate per SCP auf die Nodes:**

```shell
scp ca.crt etcd-spark-db-01.crt etcd-spark-db-01.key root@10.10.2.10:/tmp/
scp ca.crt etcd-spark-db-02.crt etcd-spark-db-02.key root@10.10.2.11:/tmp/
scp ca.crt etcd-spark-db-03.crt etcd-spark-db-03.key root@10.10.2.12:/tmp/
```

**Verschiebe die Zertifikate in die richtigen Ordner:**

```shell
sudo mkdir -p /etc/etcd/ssl
sudo mv /tmp/etcd-spark-db*.crt /etc/etcd/ssl/
sudo mv /tmp/etcd-spark-db*.key /etc/etcd/ssl/
sudo mv /tmp/ca.crt /etc/etcd/ssl/
sudo chown -R etcd:etcd /etc/etcd/
sudo chmod 600 /etc/etcd/ssl/etcd-spark-db*.key
sudo chmod 644 /etc/etcd/ssl/etcd-spark-db*.crt /etc/etcd/ssl/ca.crt
```

### Konfiguration

**Konfigurations-Datei erstellen:**

```shell
sudo nano /etc/etcd/etcd.env
```

**spark-db-01:**

```log
ETCD_NAME="spark-db-01"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER="spark-db-01=https://10.10.2.10:2380,spark-db-02=https://10.10.2.11:2380,spark-db-03=https://10.10.2.12:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.10.2.10:2380"
ETCD_LISTEN_PEER_URLS="https://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="https://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="https://10.10.2.10:2379"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_CERT_FILE="/etc/etcd/ssl/etcd-spark-db-01.crt"
ETCD_KEY_FILE="/etc/etcd/ssl/etcd-spark-db-01.key"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_PEER_CERT_FILE="/etc/etcd/ssl/etcd-spark-db-01.crt"
ETCD_PEER_KEY_FILE="/etc/etcd/ssl/etcd-spark-db-01.key"

ETCDCTL_API=3 
ETCDCTL_ENDPOINTS="https://127.0.0.1:2379" 
ETCDCTL_CACERT="/etc/etcd/ssl/ca.crt" 
ETCDCTL_CERT="/etc/etcd/ssl/etcd-spark-db-01.crt"
ETCDCTL_KEY="/etc/etcd/ssl/etcd-spark-db-01.key"
```

**spark-db-02:**

```log
ETCD_NAME="spark-db-02"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER="spark-db-01=https://10.10.2.10:2380,spark-db-02=https://10.10.2.11:2380,spark-db-03=https://10.10.2.12:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.10.2.11:2380"
ETCD_LISTEN_PEER_URLS="https://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="https://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="https://10.10.2.11:2379"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_CERT_FILE="/etc/etcd/ssl/etcd-spark-db-02.crt"
ETCD_KEY_FILE="/etc/etcd/ssl/etcd-spark-db-02.key"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_PEER_CERT_FILE="/etc/etcd/ssl/etcd-spark-db-02.crt"
ETCD_PEER_KEY_FILE="/etc/etcd/ssl/etcd-spark-db-02.key"

ETCDCTL_API=3 
ETCDCTL_ENDPOINTS="https://127.0.0.1:2379" 
ETCDCTL_CACERT="/etc/etcd/ssl/ca.crt" 
ETCDCTL_CERT="/etc/etcd/ssl/etcd-spark-db-02.crt"
ETCDCTL_KEY="/etc/etcd/ssl/etcd-spark-db-02.key"
```

**spark-db-03:**

```log
ETCD_NAME="spark-db-03"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER="spark-db-01=https://10.10.2.10:2380,spark-db-02=https://10.10.2.11:2380,spark-db-03=https://10.10.2.12:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.10.2.12:2380"
ETCD_LISTEN_PEER_URLS="https://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="https://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="https://10.10.2.12:2379"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_CERT_FILE="/etc/etcd/ssl/etcd-spark-db-03.crt"
ETCD_KEY_FILE="/etc/etcd/ssl/etcd-spark-db-03.key"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_PEER_CERT_FILE="/etc/etcd/ssl/etcd-spark-db-03.crt"
ETCD_PEER_KEY_FILE="/etc/etcd/ssl/etcd-spark-db-03.key"

ETCDCTL_API=3 
ETCDCTL_ENDPOINTS="https://127.0.0.1:2379"
ETCDCTL_CACERT="/etc/etcd/ssl/ca.crt" 
ETCDCTL_CERT="/etc/etcd/ssl/etcd-spark-db-03.crt"
ETCDCTL_KEY="/etc/etcd/ssl/etcd-spark-db-03.key"
```

```shell
source /etc/etcd/etcd.env
```

**Einen service für etcd auf allen Nodes erstellen:**

```shell
sudo nano /etc/systemd/system/etcd.service
```

**Inhalt der service Datei auf allen Nodes:**

```log
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd
EnvironmentFile=/etc/etcd/etcd.env
ExecStart=/usr/local/bin/etcd
Restart=always
RestartSec=10s
LimitNOFILE=40000
User=etcd
Group=etcd

[Install]
WantedBy=multi-user.target
```

**Ordner für `etcd` `ETCD_DATA_DIR` erstellen:**

```shell
sudo mkdir -p /var/lib/etcd
sudo chown -R etcd:etcd /var/lib/etcd
```

### Starten

**Daemon neuladen und service aktivieren:**

```shell
sudo systemctl daemon-reload
sudo systemctl enable etcd
```

**etcd starten und status prüfen:**

```shell
sudo systemctl start etcd
sudo systemctl status etcd

journalctl -xeu etcd.service
```

Die Antwort sollte wie folgt aussehen:

```log
● etcd.service - etcd key-value store
     Loaded: loaded (/etc/systemd/system/etcd.service; enabled; preset: enabled)
     Active: active (running) since Mon 2024-12-02 14:09:30 CST; 2s ago
       Docs: https://github.com/etcd-io/etcd
   Main PID: 7266 (etcd)
      Tasks: 9 (limit: 4612)
     Memory: 29.3M (peak: 30.0M)
        CPU: 246ms
     CGroup: /system.slice/etcd.service
             └─7266 /usr/local/bin/etcd
```

### Verifizierung

**Sobald das Cluster läuft können wir das ganze verifizieren:**

```shell
etcdctl endpoint health
etcdctl member list
```

**Das ganze sollte auf der spark-db-01 aussehen:**

```log
127.0.0.1:2379 is healthy: successfully committed proposal: took = 1.786976ms
eb8ee14ab5150b4, started, postgresql-01, http://10.10.2.10:2380, http://10.10.2.10:2379, false
34e89b244664f02d, started, postgresql-02, http://10.10.2.11:2380, http://10.10.2.11:2379, false
8ee2a9473a41c400, started, postgresql-03, http://10.10.2.12:2380, http://10.10.2.12:2379, false
```

**Falls die Verbindung nicht hergestellt werden konnte, versuch folgendes:**

```shell
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS="https://127.0.0.1:2379"
export ETCDCTL_CACERT="/etc/etcd/ssl/ca.crt"
export ETCDCTL_CERT="/etc/etcd/ssl/etcd-spark-db-01.crt"
export ETCDCTL_KEY="/etc/etcd/ssl/etcd-spark-db-01.key"

etcdctl endpoint health
```

Das ganze muss auf allen 3 Nodes gemacht werden.

**Überall etcd neustarten:**

```shell
sudo systemctl restart etcd
```

```shell
 sudo etcdctl \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/etcd/ssl/ca.crt \
--cert=/etc/etcd/ssl/etcd-spark-db-01.crt \
--key=/etc/etcd/ssl/etcd-spark-db-01.key \
endpoint health

sudo etcdctl \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/etcd/ssl/ca.crt \
--cert=/etc/etcd/ssl/etcd-spark-db-01.crt \
--key=/etc/etcd/ssl/etcd-spark-db-01.key \
member list
```

**Du kannst überprüfen, wer der Anführer ist, indem du folgenden Befehl ausführen:**

```shell
sudo etcdctl \
--endpoints=https://10.10.2.10:2379,https://10.10.2.11:2379,https://10.10.2.12:2379 \
  --cacert=/etc/etcd/ssl/ca.crt \
  --cert=/etc/etcd/ssl/etcd-spark-db-01.crt \
  --key=/etc/etcd/ssl/etcd-spark-db-01.key \
  endpoint status --write-out=table
```

## PostgreSQL und Patroni

### Zertifikate

Sobald alle eingerichtet ist, können wir postgres und patroni konfigurieren.

**Dafür folgende Ordner anlegen:**

```shell
sudo mkdir -p /var/lib/postgresql/data
sudo mkdir -p /var/lib/postgresql/ssl
```

**Zertifikate anlegen:**

```shell
openssl genrsa -out server.key 2048 # private key
```

```shell
openssl req -new -key server.key -out server.req # csr
```

```shell
openssl req -x509 -key server.key -in server.req -out server.crt -days 7300 # generate cert, valid for 20 years
```

**Berechtigungen anpassen:**

```shell
chmod 600 server.key
```

**Nachdem, müssen die Zertifikate auf die anderen Servern kopiert werden:**

```shell
scp server.crt server.key server.req root@10.10.2.10:/tmp
scp server.crt server.key server.req root@10.10.2.11:/tmp
scp server.crt server.key server.req root@10.10.2.12:/tmp
```

**Zertifikate auf den Servern verschieben:**

```shell
cd /tmp 
sudo mv server.crt server.key server.req /var/lib/postgresql/ssl
```

**Postgres user Berechtigungen vergeben:**

```shell
sudo chmod 600 /var/lib/postgresql/ssl/server.key
sudo chmod 644 /var/lib/postgresql/ssl/server.crt
sudo chmod 600 /var/lib/postgresql/ssl/server.req
sudo chown postgres:postgres /var/lib/postgresql/data
sudo chown postgres:postgres /var/lib/postgresql/ssl/server.*
sudo chown -R postgres:postgres /var/lib/postgresql/data
sudo chmod 0700 /var/lib/postgresql/data
```

**Postgres user Berechtigungen vergeben:**

```
sudo apt update
sudo apt install -y acl
```

**spark-db-01:**

```shell
sudo setfacl -m u:postgres:r /etc/etcd/ssl/ca.crt
sudo setfacl -m u:postgres:r /etc/etcd/ssl/etcd-spark-db-01.crt
sudo setfacl -m u:postgres:r /etc/etcd/ssl/etcd-spark-db-01.key
```

**spark-db-02:**

```shell
sudo setfacl -m u:postgres:r /etc/etcd/ssl/ca.crt
sudo setfacl -m u:postgres:r /etc/etcd/ssl/etcd-spark-db-02.crt
sudo setfacl -m u:postgres:r /etc/etcd/ssl/etcd-spark-db-02.key
```

**spark-db-03:**

```shell
sudo setfacl -m u:postgres:r /etc/etcd/ssl/ca.crt
sudo setfacl -m u:postgres:r /etc/etcd/ssl/etcd-spark-db-03.crt
sudo setfacl -m u:postgres:r /etc/etcd/ssl/etcd-spark-db-03.key
```

## Patroni

### Patroni installieren

```shell
sudo apt install -y patroni
```

**`ssh` in spark-db-01 und Ordner für `patroni` anlegen:**

```shell
sudo mkdir -p /etc/patroni/
```

### Patroni konfigurieren

**Konfigurationsdatei anlegen und bearbeiten:**

```shell
sudo nano /etc/patroni/config.yml
```

**spark-db-01:**

```shell
scope: postgresql-cluster
namespace: /service/
name: spark-db-01  # node1

etcd3:
  hosts: 10.10.2.10:2379,10.10.2.11:2379,10.10.2.12:2379  # etcd cluster nodes
  protocol: https
  cacert: /etc/etcd/ssl/ca.crt
  cert: /etc/etcd/ssl/etcd-spark-db-01.crt  # node1's etcd certificate
  key: /etc/etcd/ssl/etcd-spark-db-01.key  # node1's etcd key

restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.10.2.10:8008  # IP for node1's REST API
  certfile: /var/lib/postgresql/ssl/server.pem

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576  # Failover parameters
    postgresql:
        parameters:
            ssl: 'on'  # Enable SSL
            ssl_cert_file: /var/lib/postgresql/ssl/server.crt  # PostgreSQL server certificate
            ssl_key_file: /var/lib/postgresql/ssl/server.key  # PostgreSQL server key
        pg_hba:  # Access rules
        - hostssl replication replicator 127.0.0.1/32 md5
        - hostssl replication replicator 10.10.2.10/32 md5
        - hostssl replication replicator 10.10.2.11/32 md5
        - hostssl replication replicator 10.10.2.12/32 md5
        - hostssl all all 127.0.0.1/32 md5
        - hostssl all all 0.0.0.0/0 md5
  initdb:
    - encoding: UTF8
    - data-checksums

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.10.2.10:5432  # IP for node1's PostgreSQL
  data_dir: /var/lib/postgresql/data
  bin_dir: /usr/lib/postgresql/17/bin  # Binary directory for PostgreSQL 17
  authentication:
    superuser:
      username: postgres
      password: cnV2abjbDpbh64e12987wR4mj5kQ3456Y0Qfa  # Superuser password - be sure to change
    replication:
      username: replicator
      password: sad9a23jga8jsuedrwtsskj74567suiuwe23a  # Replication password - be sure to change
  parameters:
    max_connections: 100
    shared_buffers: 256MB

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
```

**spark-db-02:**

```shell
scope: postgresql-cluster
namespace: /service/
name: spark-db-02  # Unique name for Node 2

etcd3:
  hosts: 10.10.2.10:2379,10.10.2.11:2379,10.10.2.12:2379  # etcd cluster nodes
  protocol: https
  cacert: /etc/etcd/ssl/ca.crt
  cert: /etc/etcd/ssl/etcd-spark-db-02.crt  # Node 2's etcd certificate
  key: /etc/etcd/ssl/etcd-spark-db-02.key  # Node 2's etcd key

restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.10.2.11:8008  # IP for Node 2's REST API
  certfile: /var/lib/postgresql/ssl/server.pem

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
        parameters:
        ssl: 'on'
        ssl_cert_file: /var/lib/postgresql/ssl/server.crt
        ssl_key_file: /var/lib/postgresql/ssl/server.key
        pg_hba:
        - hostssl replication replicator 127.0.0.1/32 md5
        - hostssl replication replicator 10.10.2.10/32 md5
        - hostssl replication replicator 10.10.2.11/32 md5
        - hostssl replication replicator 10.10.2.12/32 md5
        - hostssl all all 127.0.0.1/32 md5
        - hostssl all all 0.0.0.0/0 md5
  initdb:
    - encoding: UTF8
    - data-checksums

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.10.2.11:5432  # IP for Node 2's PostgreSQL
  data_dir: /var/lib/postgresql/data
  bin_dir: /usr/lib/postgresql/17/bin
  authentication:
    superuser:
      username: postgres
      password: cnV2abjbDpbh64e12987wR4mj5kQ3456Y0Qfa  # Superuser password (provided)
    replication:
      username: replicator
      password: sad9a23jga8jsuedrwtsskj74567suiuwe23a  # Replication password (provided)
  parameters:
    max_connections: 100
    shared_buffers: 256MB

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
```

**spark-db-03:**

```shell
scope: postgresql-cluster
namespace: /service/
name: spark-db-03  # Unique name for Node 3

etcd3:
  hosts: 10.10.2.10:2379,10.10.2.11:2379,10.10.2.12:2379 #etcd cluster nodes
  protocol: https
  cacert: /etc/etcd/ssl/ca.crt
  cert: /etc/etcd/ssl/etcd-spark-db-03.crt  # Node 3's etcd certificate
  key: /etc/etcd/ssl/etcd-spark-db-03.key  # Node 3's etcd key

restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.10.2.12:8008  # IP for Node 3's REST API
  certfile: /var/lib/postgresql/ssl/server.pem

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
        parameters:
        ssl: 'on'
        ssl_cert_file: /var/lib/postgresql/ssl/server.crt
        ssl_key_file: /var/lib/postgresql/ssl/server.key
        pg_hba:
        - hostssl replication replicator 127.0.0.1/32 md5
        - hostssl replication replicator 10.10.2.10/32 md5
        - hostssl replication replicator 10.10.2.11/32 md5
        - hostssl replication replicator 10.10.2.12/32 md5
        - hostssl all all 127.0.0.1/32 md5
        - hostssl all all 0.0.0.0/0 md5
  initdb:
    - encoding: UTF8
    - data-checksums

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.10.2.12:5432  # IP for Node 3's PostgreSQL
  data_dir: /var/lib/postgresql/data
  bin_dir: /usr/lib/postgresql/17/bin
  authentication:
    superuser:
      username: postgres
      password: "cnV2abjbDpbh64e12987wR4mj5kQ3456Y0Qfa"  # Superuser password (provided)
    replication:
      username: replicator
      password: sad9a23jga8jsuedrwtsskj74567suiuwe23a  # Replication password (provided)
  parameters:
    max_connections: 100
    shared_buffers: 256MB

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
```

---

## Patroni Certificates

Let's also use a certificate for this (requires a PEM):

```shell
sudo sh -c 'cat /var/lib/postgresql/ssl/server.crt /var/lib/postgresql/ssl/server.key > /var/lib/postgresql/ssl/server.pem'
sudo chown postgres:postgres /var/lib/postgresql/ssl/server.pem
sudo chmod 600 /var/lib/postgresql/ssl/server.pem
```

We can verify with:

```shell
sudo openssl x509 -in /var/lib/postgresql/ssl/server.pem -text -noout
```

## Starting Patroni and HA Cluster

Restart the service

```shell
sudo systemctl restart patroni
```

Check logs

```shell
journalctl -u patroni -f
```

Should see something like:

```log
Dec 03 22:16:05 spark-db-01 patroni[770]: 2024-12-03 22:16:05,399 INFO: no action. I am (postgresql-01), the leader with the lock
Dec 03 22:16:15 spark-db-01 patroni[770]: 2024-12-03 22:16:15,399 INFO: no action. I am (postgresql-01), the leader with the lock
```

and

```log
Dec 03 22:16:21 spark-db-02 patroni[768]: 2024-12-03 22:16:21,780 INFO: Lock owner: postgresql-01; I am postgresql-02
Dec 03 22:16:21 spark-db-02 patroni[768]: 2024-12-03 22:16:21,823 INFO: bootstrap from leader 'postgresql-01' in progress
```

## Reconfiguring our etcd Cluster

```shell
sudo nano /etc/etcd/etcd.env
```

Change

```log
ETCD_INITIAL_CLUSTER_STATE="new"
```

to

```log
ETCD_INITIAL_CLUSTER_STATE="existing"
```

Do this on all 3 nodes!

## Verifying Our Postgres Cluster

We now have a HA Postgres cluster!

However we don’t always know who the leader is so we can’t use a fixed DB node IP directly.

We can test the Patroni endpoint to see who is leader:

```shell
curl -k https://10.10.2.10:8008/primary
curl -k https://10.10.2.11:8008/primary
curl -k https://10.10.2.12:8008/primary
```

## Editing your pg_hba after bootstrapping

If you ever want to see your global config you can with

```shell
sudo patronictl -c /etc/patroni/config.yml show-config
```

If you ever want to edit it, you can with:

```shell
sudo patronictl -c /etc/patroni/config.yml edit-config
```

After saving these will be replicated to all nodes. Note you might want to update your bootstrap config at some point.

---

## HAProxy

### Installing HAProxy

This is where HAProxy comes in. Install HAProxy on your proxy nodes.

```shell
sudo apt -y install haproxy
```

Once installed we need to add some config

```shell
sudo nano /etc/haproxy/haproxy.cfg
```

Example minimal config (health-checks via Patroni REST API on 8008 with HTTPS):

```cfg
frontend postgres_frontend
    bind *:5432
    mode tcp
    default_backend postgres_backend

backend postgres_backend
    mode tcp
    option tcp-check
    option httpchk GET /primary
    http-check expect status 200
    timeout connect 5s
    timeout client 30s
    timeout server 30s
    # Health checks hit port 8008 (HTTPS) while traffic goes to 5432
    server spark-db-01 10.10.2.10:5432 check port 8008 check-ssl verify none
    server spark-db-02 10.10.2.11:5432 check port 8008 check-ssl verify none
    server spark-db-03 10.10.2.12:5432 check port 8008 check-ssl verify none
```

Do this on all HAProxy nodes.

### Starting HAProxy

```shell
sudo systemctl reload haproxy
```

Check logs

```shell
sudo tail -f /var/log/syslog | grep haproxy
```

---

## keepalived

### Installing keepalived

Now we need to install keepalived to create a VIP (Virtual IP). Use your VIP 10.10.2.1.

```shell
sudo apt update
sudo apt install keepalived -y
```

### Configuring keepalived

Apply a configuration file:

```shell
sudo nano /etc/keepalived/keepalived.conf
```

Example for three HAProxy nodes with VIP 10.10.2.1 (adjust `interface` to your NIC):

haproxy1

```cfg
global_defs {
    enable_script_security
    script_user keepalived_script
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 2
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass jh75hf9g
    }
    virtual_ipaddress {
        10.10.2.1
    }
    track_script {
        check_haproxy
    }
}
```

haproxy2

```cfg
global_defs {
    enable_script_security
    script_user keepalived_script
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 2
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 90
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass jh75hf9g
    }
    virtual_ipaddress {
        10.10.2.254
    }
    track_script {
        check_haproxy
    }
}
```

haproxy3

```cfg
global_defs {
    enable_script_security
    script_user keepalived_script
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 2
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 80
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass jh75hf9g
    }
    virtual_ipaddress {
        10.10.2.254
    }
    track_script {
        check_haproxy
    }
}
```

Create a check script on each

```shell
sudo nano /etc/keepalived/check_haproxy.sh
```

```bash
#!/bin/bash

# Define the port to check (e.g., HAProxy frontend port)
PORT=5432

# Check if HAProxy is running
if ! pidof haproxy > /dev/null; then
    echo "HAProxy is not running"
    exit 1
fi

# Check if HAProxy is listening on the expected port
if ! ss -ltn | grep -q ":${PORT}"; then
    echo "HAProxy is not listening on port ${PORT}"
    exit 2
fi

# All checks passed
exit 0
```

We need to add a user to execute these scripts
```shell
sudo useradd -r -s /bin/false keepalived_script
```

```shell
sudo chmod +x /etc/keepalived/check_haproxy.sh
sudo chown keepalived_script:keepalived_script /etc/keepalived/check_haproxy.sh
sudo chmod 700 /etc/keepalived/check_haproxy.sh
```

### Starting keepalived

```shell
sudo systemctl restart keepalived
```

### Verifying keepalived

Check logs

```shell
sudo journalctl -u keepalived -f
```

We should now be able to ping the VIP

```shell
ping 10.10.2.254
```

---

## PGAdmin

### Connecting with PGAdmin

Connected with a client

`https://www.pgadmin.org/`

Connect to your VIP `10.10.2.1` and use the postgres user and password.

### Adding Data

Create a table with data

```sql
-- Create a table for Nintendo characters
CREATE TABLE nintendo_characters (
    character_id SERIAL PRIMARY KEY, -- Unique identifier for each character
    name VARCHAR(50) NOT NULL,       -- Name of the character
    game_series VARCHAR(50),         -- Game series the character belongs to
    debut_year INT,                  -- Year the character debuted
    description TEXT,                -- Brief description of the character
    is_playable BOOLEAN DEFAULT TRUE -- Whether the character is playable
);

-- Insert some example characters
INSERT INTO nintendo_characters (name, game_series, debut_year, description, is_playable)
VALUES
    ('Mario', 'Super Mario', 1981, 'The iconic plumber and hero of the Mushroom Kingdom.', TRUE),
    ('Link', 'The Legend of Zelda', 1986, 'A courageous hero tasked with saving Hyrule.', TRUE),
    ('Samus Aran', 'Metroid', 1986, 'A bounty hunter equipped with a powerful Power Suit.', TRUE),
    ('Donkey Kong', 'Donkey Kong', 1981, 'A powerful gorilla and protector of the jungle.', TRUE),
    ('Princess Zelda', 'The Legend of Zelda', 1986, 'The princess of Hyrule and possessor of the Triforce of Wisdom.', FALSE),
    ('Bowser', 'Super Mario', 1985, 'The King of the Koopas and Marios arch-nemesis.', FALSE),
    ('Kirby', 'Kirby', 1992, 'A pink puffball with the ability to inhale enemies and copy their powers.', TRUE),
    ('Pikachu', 'Pokémon', 1996, 'An Electric-type Pokémon and mascot of the Pokémon series.', TRUE),
    ('Fox McCloud', 'Star Fox', 1993, 'A skilled pilot and leader of the Star Fox team.', TRUE),
    ('Captain Falcon', 'F-Zero', 1990, 'A bounty hunter and expert racer known for his Falcon Punch.', TRUE);

-- Select all rows to verify the table creation and data insertion
SELECT * FROM nintendo_characters;
```

```sql
-- Insert additional Nintendo characters into the table
INSERT INTO nintendo_characters (name, game_series, debut_year, description, is_playable)
VALUES
    ('Yoshi', 'Super Mario', 1990, 'A friendly green dinosaur and Marios trusted companion.', TRUE),
    ('Luigi', 'Super Mario', 1983, 'Marios younger brother and a skilled ghost hunter.', TRUE),
    ('King Dedede', 'Kirby', 1992, 'The self-proclaimed king of Dream Land and occasional ally of Kirby.', TRUE),
    ('Meta Knight', 'Kirby', 1993, 'A mysterious swordsman who often challenges Kirby.', TRUE),
    ('Marth', 'Fire Emblem', 1990, 'A legendary hero and prince from the Fire Emblem series.', TRUE),
    ('Ness', 'EarthBound', 1994, 'A young boy with psychic powers and a bat-wielding hero.', TRUE),
    ('Jigglypuff', 'Pokémon', 1996, 'A Balloon Pokémon known for its singing abilities.', TRUE),
    ('Villager', 'Animal Crossing', 2001, 'A customizable character from the Animal Crossing series.', TRUE),
    ('Isabelle', 'Animal Crossing', 2012, 'A cheerful assistant who helps manage your town.', TRUE),
    ('Ganondorf', 'The Legend of Zelda', 1998, 'The King of Evil and nemesis of Link.', TRUE);

SELECT * FROM nintendo_characters;
```

If you want to clean this data up, you can DROP the table

```sql
-- Drop the nintendo_characters table if it exists
DROP TABLE IF EXISTS nintendo_characters;
```

---

## Troubleshooting

Reset all data but certs and start over

```shell
sudo systemctl stop patroni
sudo systemctl stop etcd
sudo rm -rf /var/lib/etcd/
sudo rm -rf /var/lib/postgresql/data/
sudo mkdir -p /var/lib/postgresql/data
sudo mkdir -p /var/lib/etcd/
sudo chown etcd:etcd /var/lib/etcd/
sudo setfacl -m u:postgres:r /etc/etcd/ssl/ca.crt
sudo setfacl -m u:postgres:r /etc/etcd/ssl/etcd-node*
sudo systemctl start etcd
sudo systemctl start patroni
```
