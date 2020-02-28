# Consul - Commands 

Contents

- [Installing Consul](#Installing-Consul)
- [Service Discovery](#Service-Discovery)
- [Traffic Management](#Traffic-Management)

Copy and paste command as you practice.

## Installing Consul

### Prerequisite

### Check if keepalived is running
```
kubectl -n keepalived get pods
```

### Clone scripts
```
cd ~/ # Switch to home directory
git clone https://github.com/servicemeshbook/consul.git
cd consul
git checkout 1.6.1
cd scripts
```

### Download v1.6.1. package for Linux AMD64
```
wget https://releases.hashicorp.com/consul/1.6.1/consul_1.6.1_linux_amd64.zip
```

### Extract consul from the zip archive
```
unzip consul_1.6.1_linux_amd64.zip
sudo mv consul /bin
```

### Check the Consul version
```
consul version
```

### Installing Consul in Kubernetes

### Create persistent volumes directory
```
sudo mkdir -p /var/lib/consul{0,1,2}
```

### Create a consul namespace
```
kubectl create ns consul
```

### Grant cluster_admin to the namespace consul.
```
kubectl create clusterrolebinding consul-role-binding --clusterrole=cluster-admin --group=system:serviceaccounts:consul
```

### Create a storage class and 3 persistent volumes.
```
kubectl -n consul apply -f 01-create-pv-consul.yaml
```

### Downloading Consul Helm Chart

### Find out available versions of the Consul helm for Kubernetes
```
curl -L -s https://api.github.com/repos/hashicorp/consul-helm/tags | grep "name"
```

### Download consul-helm
```
cd # switch to home dir
export CONSUL_HELM_VERSION=0.11.0
curl -LOs https://github.com/hashicorp/consul-helm/archive/v${CONSUL_HELM_VERSION}.tar.gz
tar xfz v${CONSUL_HELM_VERSION}.tar.gz
```

### Modify two parameters
```
sed -i 's/failureThreshold:.*/failureThreshold: 30/g' \
~/consul-helm-${CONSUL_HELM_VERSION}/templates/server-statefulset.yaml

sed -i 's/initialDelaySeconds:.*/initialDelaySeconds: 60/g' \
~/consul-helm-${CONSUL_HELM_VERSION}/templates/server-statefulset.yaml 
```

### Installing Consul
```
cd ~/consul/scripts # Switch to scripts for this exercise
```

### Create a new Consul Cluster in Kubernetes
```
cat 02-consul-values.yaml
helm install ~/consul-helm-${CONSUL_HELM_VERSION}/ --name consul \
--namespace consul --set fullnameOverride=consul -f ./02-consul-values.yaml
```

### Make sure that the persistent volume claims are created 
```
kubectl -n consul get pvc
```
### Check if Consul servers are in a Ready 1/1
```
kubectl -n consul get pods
```

### Deploying Consul Server and Client
```
kubectl -n consul get sts
```

### Check the version of the Consul running in Kubernetes
```
kubectl -n consul exec -it consul-server-0 -- consul version
```

### Find out which server is the leader
```
kubectl -n consul logs consul-server-0 | grep -i leader
```

### Consul clients are installed as a DaemonSet
```
kubectl -n consul get ds
```

### Connecting Consul DNS to Kubernetes

### Consul runs its own DNS for service discovery
```
kubectl -n consul get svc
```
### We need to connect consul-dns service to Kubernetes DNS
```
cat 03-create-coredns-configmap.sh 
chmod +x 03-create-coredns-configmap.sh
./03-create-coredns-configmap.sh 
```

### Check addition of consul DNS server
```
kubectl -n kube-system get cm coredns -o yaml
```

### Consul server in VM

### Find out the end-points for the consul-server
```
kubectl -n consul get ep
```

### Query the node names using REST API.
```
curl -s localhost:8500/v1/catalog/nodes | json_reformat
```

### Check members of the Consul cluster using one of the Kubernetes Consul pods
```
kubectl -n consul exec -it consul-server-0 -- consul members
```

### Check the same from the VM
```
consul members
```

### Use consul info command
```
kubectl -n consul exec -it consul-server-0 -- consul info
```

### End of Consul Install commands

## Service Discovery

### Installing Demo Application

### Let's create backend counting and frontend dashboard services

```
cat 04-counting-demo.yaml
kubectl -n consul apply -f 04-counting-demo.yaml
```

### Check counting and dashboard pods
```
kubectl -n consul get pods
```

### Describe one of the microservice and check the sidecar proxy injection
```
kubectl -n consul describe pod counting
```

### Defining Ingress for Consul dashboard
```
export INGRESS_HOST=$(kubectl -n kube-system get service nginx-controller \
-o jsonpath='{.status.loadBalancer.ingress..ip}') ; echo $INGRESS_HOST

sudo sed -i '/webconsole.consul.local/d' /etc/hosts
echo "$INGRESS_HOST webconsole.consul.local" | sudo tee -a /etc/hosts

cat 05-create-ingress.yaml
kubectl apply -f 05-create-ingress.yaml
```

### Service Discovery

### Make sure you are in ~/consul/scripts directory
```
cd ~/consul/scripts 
```

### Find out the node port for the demo application's dashboard-service
```
kubectl -n consul get svc dashboard-service
```

### Note the node port number from the above command and open URL http://192.168.142.101:<port> in browser


### Open URL http://webconsole.consul.local from another tab

### Service discovery - command line

```
consul config list -kind service-defaults
```

### Mutual TLS

### Check the log of the sidecar proxy for TLS
```
kubectl -n consul logs counting -c consul-connect-envoy-sidecar | grep tls
```

### The leaf certificates time to live is 72 hours. Verify this by
```
curl -s http://consul-server.consul.svc.cluster.local:8500/v1/connect/ca/configuration | json_reformat
```

### The root certificates can be viewed as through the following REST API call
```
curl -s http://consul-server.consul.svc.cluster.local:8500/v1/connect/ca/roots | json_reformat
```

### Key-Value store

```
consul kv put redis/config/minconns 1
consul kv put redis/config/maxconns 25
consul kv put redis/config/users/admin password
```

### Extract key from the store along with other metadata. 
```
consul kv get --detailed redis/config/minconns
```

### Get all values from the key-value store recursively
```
consul kv get -recurse
```

### The keys can also be obtained through REST API
```
curl -s http://localhost:8500/v1/kv/redis/config/minconns | json_reformat 
```

### Monitoring and Metrics
```
consul monitor
```

### watch for changes in a given data view from Consul
```
consul watch -type=service -service=consul
```

### Metrics Collection
```
curl -s http://localhost:8500/v1/agent/metrics | json_reformat
```

### Registering External Service
```
kubectl -n consul -c counting cp counting:counting-service ~/counting-service
chmod +x ~/counting-service
sudo cp ~/counting-service /bin
```

### Define a systemd service in the local VM to run the counting service
```
cat 06-create-systemd-service.sh
chmod +x 06-create-systemd-service.sh
sudo ./06-create-systemd-service.sh
```

### Enable and start external-counting service
```
sudo systemctl enable external-counting
sudo systemctl start external-counting
sudo systemctl status external-counting
```

### Test external counting service
```
curl http://localhost:10001/health
```

### we will register this service with the Consul agent
```
cat 07-define-external-service-json.sh
chmod +x 07-define-external-service-json.sh
./07-define-external-service-json.sh 
curl -X PUT -d @external-counting.json http://localhost:8500/v1/agent/service/register
```

### The external service should show in the web console of Consul.


### End of Consul Service Discovery commands

## Traffic Management

### Make sure you are in ~/consul/scripts directory
```
cd ~/consul/scripts 
```

### Implementing L7 Configuration

### Create an instance of service-defaults for service web that will use http protocol

```
cat 08-service-defaults-web.hcl
consul config write 08-service-defaults-web.hcl
```

### List all service-defaults registered in Consul
```
consul config list -kind service-defaults
```

### Read web service-defaults configuration entry that we just created
```
consul config read -kind service-defaults -name web
```

### Define a JSON configuration to define http protocol for the web service

```
cat 09-service-defaults-api.json
```

### Create service-defaults for the web service to use http protocol using Consul REST API
```
 curl -XPUT --data @09-service-defaults-api.json http://localhost:8500/v1/config ; echo 
```

### List web service-defaults that we just created.
```
curl -s http://localhost:8500/v1/config/service-defaults/api | json_reformat 

```

### An example of service-resolver for allowing subset based on service catalog metadata
```
cat 10-service-resolver-api.hcl
consul config write 10-service-resolver-api.hcl
consul config list -kind service-resolver
```

### Notice that the api sevice-resolver is created.

### Deploying Demo Application

### Create a web microservice pod and its Kubernetes service web

```
cat 11-web-deployment.yaml 
kubectl -n consul apply -f 11-web-deployment.yaml 
```

### Now, check web pod and web service
```
kubectl -n consul get pods -l app=web
kubectl -n consul get svc web
```

### Create api-deployment-v1 and api-deployment-v2
```
cat 12-api-v1-deployment.yaml
kubectl -n consul apply -f 12-api-v1-deployment.yaml 

cat 13-api-v2-deployment.yaml 
kubectl -n consul apply -f 13-api-v2-deployment.yaml 
```

### Check api-v1 service at node port 30146 and it calls api-v1 pod
```
curl http://localhost:30146
```

### Check api-v2 service at node port 30147 and it calls api-v2 pod
```
curl http://localhost:30147
```

### Directing Traffic to default subset

### Run curl -s http://localhost:30145 and check the output
```
curl -s http://localhost:30145
```

### When we call Kubernetes service web at node port 30145, it calls microservice from web pod

### Repeat the same curl command 10 times and you will notice 
### that the traffic is always shifted to api-deployment-v1 pod
```
curl -s http://localhost:30145?[1-10] | grep "Pod Name.*api"
```

### Canary Deployment
### Route 99% of traffic to subset v1 and 1% to subset v2
```
cat 14-service-splitter-canary.hcl
consul config write 14-service-splitter-canary.hcl
consul config list -kind service-splitter
```

### Repeat the same curl command 200 times
```
curl -s http://localhost:30145?[1-200] | grep "Pod Name.*api-v1"
curl -s http://localhost:30145?[1-200] | grep "Pod Name.*api-v2"
```

### Round Robin Traffic
### Split in a round-robin using 50-50 weight to both the services
```
cat 15-service-splitter-round-robin.hcl
consul config write 15-service-splitter-round-robin.hcl
consul config list -kind service-splitter
```

### Repeat same curl to check split in traffic 
```
curl -s http://localhost:30145?[1-10] | grep "Pod Name.*api"
```

### Shifting Traffic Permanently

### Create service-splitter for Consul service api using Consul CLI 

```
cat 16-service-splitter-100-shift.hcl
consul config write 16-service-splitter-100-shift.hcl
consul config list -kind service-splitter
```

### Repeat the same curl command 10 times.
```
curl -s http://localhost:30145?[1-10] | grep "Pod Name.*api"
```

### Notice that the traffic is now permanently shifted to api-v2

### Path-Based Traffic Routing

### Delete the previous deployment of the web and api.

```
kubectl -n consul delete -f 11-web-deployment.yaml

kubectl -n consul delete -f 12-api-v1-deployment.yaml

kubectl -n consul delete -f 13-api-v2-deployment.yaml
```

### Check web and api service-defaults
```
consul config list -kind service-defaults
consul config read -kind service-defaults -name web
consul config read -kind service-defaults -name api
```

### Define api service-router.
```
cat 17-service-router.hcl
```

### Create an api service-router
```
consul config write 17-service-router.hcl
```

### Create Kubernetes web service and deployment
```
cat 18-web-deployment.yaml
kubectl apply -f 18-web-deployment.yaml
```

### Create an api-v1 deployment.
```
cat 19-api-v1-deployment.yaml
kubectl apply -f 19-api-v1-deployment.yaml
```

### Create an api-v2 deployment.
```
cat 20-api-v2-deployment.yaml
kubectl apply -f 20-api-v2-deployment.yaml
```

### Run curl at node port 30145 without using any path
```
curl -s http://localhost:30145
```
### Notice that traffic is shifted to api-v2 permanently

### Run the same curl command by using path /v1 
```
curl -s http://localhost:30145/v1
```

### Notice that traffic is routed to api-v2 permanently using /v2 path

### Run the same curl command by using path /v2 
```
curl -s http://localhost:30145/v2
```

### Notice that the traffic is routed to api-v2 based upon path

### End of Consul Traffic Management commands