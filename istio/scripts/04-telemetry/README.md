# Istio - Telemetry

## Commands used in Chapter 13 - Telemetry

### Change directory

```
cd ~/istio
cd scripts/04-telemetry
```

### Make sure that all istio-lab pods show Ready state 2/2.

```
kubectl -n istio-lab get pods
```

### Edit /etc/hosts file and add entries for the following additional hosts
```
sudo vi /etc/hosts

192.168.142.249 grafana.istio.io grafana
192.168.142.249 prometheus.istio.io prometheus
192.168.142.249 kiali.istio.io kiali
192.168.142.249 jaeger.istio.io jaeger
```

### Check the services and note the port numbers on which these Web-UI services for telemetry are running

```
kubectl -n istio-system get svc | grep -E "grafana|prometheus|kiali|jaeger"
```

### Create virtual services for Grafana, Prometheus, Kiali and Jaeger

```
cat 01-create-vs-grafana-jaeger-prometheus.yaml
kubectl -n istio-system apply -f 01-create-vs-grafana-jaeger-prometheus.yaml
```

### Check through istioctl command and then using sidecar proxy internal web UI

```
export INGRESS_HOST=$(kubectl -n istio-system get pods -l app=istio-ingressgateway -o jsonpath='{.items..metadata.name}')

istioctl proxy-config route $INGRESS_HOST.istio-system -o json
```

### Scroll up and see virtual host labeled - "cluster" has been pushed to the sidecar proxy

### Check the same through the sidecar proxy internal Web UI

```
kubectl -n istio-system port-forward $INGRESS_HOST 15000
```

### From inside the VM, open a browser and open http://localhost:15000 and click link config_dump

### Press CTRL-C from the command line window to stop port forwarding

### Double confirm the same from a separate pod running in the istio-lab namespace
```
RATING_POD=$(kubectl -n istio-lab get pods -l app=ratings -o jsonpath='{.items[0].metadata.name}') ; echo $RATING_POD
kubectl -n istio-lab port-forward $RATING_POD 15000
```

### Run the following URL from a browser within VM, http://localhost:15000/config_dump 
### and scroll down to see the routing rule pushed down for the virtual systems that for the telemetry

### Show Web UI for any control plane pod
```
INGRESS_HOST=$(kubectl -n istio-system get pods -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}') ; echo $INGRESS_HOST
istioctl dashboard controlz $INGRESS_HOST.istio-system
```

### open ControlZ plane web ui locally on our laptop/MacBook. Press CTRL-C to stop dashboard

### Open Envoy admin dashboard of a microservice
```
RATING_POD=$(kubectl -n istio-lab get pods -l app=ratings -o jsonpath='{.items[0].metadata.name}') ; echo $RATING_POD
istioctl dashboard envoy $RATING_POD.istio-lab
```

### Open a dashboard for Grafana, Jaeger, Kiali, and Prometheus
```
istioctl dashboard grafana

istioctl dashboard jaeger

istioctl dashboard prometheus

istioctl dashboard kiali
```


### Launch the Prometheus UI. From the browser within VM, launch http://prometheus.istio.io and the GUI should open

## Metrics Collection

### Check attributemanifest available in Kubernetes

```
kubectl -n istio-system get attributemanifest
```

### Check the attribute list for istioproxy and notice the list of attributes available for Istio

```
kubectl -n istio-system get attributemanifest istioproxy -o yaml
```

### From above see the list of attributes such as errorcode, error_message, connection.duration and these attributes are generated and consumed by different services

## Collect new metrics

### Implement new metrics collection that can be pushed down to the Mixer and then Mixer pushes those down to the Envoy proxy level for the actual work

### Create a metric instance

```
cat 02-create-metric-instance.yaml
kubectl -n istio-system apply -f 02-create-metric-instance.yaml
```

### Create a Prometheus handler using a double request counter created
```
cat 03-create-prometheus-handler.yaml
kubectl -n istio-system apply -f 03-create-prometheus-handler.yaml
```

### Create a rule to send metric data to Prometheus handler
```
cat 04-create-rule-to-send-metric-to-prometheus.yaml
kubectl -n istio-system apply -f 04-create-rule-to-send-metric-to-prometheus.yaml
```

### Refresh page http://bookinfo.istio.io in your browser within VM
### Switch to the Prometheus Web UI at http://prometheus.istio.io and follow hands-on from the book

## Database metrics

### Create a handler for bytes sent and received for the MongoDb database service

```
cat 05-create-metric-instance.yaml
kubectl -n istio-system apply -f 05-create-metric-instance.yaml
```

### Create a Prometheus handler
```
cat 06-create-prometheus-handler.yaml
kubectl -n istio-system apply -f 06-create-prometheus-handler.yaml
```

### Create a rule to send the sent and received metrics instances to Prometheus handler
```
cat  07-create-rule-to-send-metric-to-prometheus.yaml
kubectl -n istio-system apply -f 07-create-rule-to-send-metric-to-prometheus.yaml
```

### Follow instuctions in book for database metrics

## Distributed Tracing

### Sidecar proxy adds root span before passing the request to the application container
```
curl -s http://httpbin.istio.io/headers
```

### Trace sampling

```
kubectl -n istio-system get deploy istio-pilot -o yaml | grep "name: PILOT_TRACE_SAMPLING" -A1
```

### Modify the sampling rate to 99%.

```
kubectl -n istio-system patch deployment istio-pilot --type json -p '[{"op": "replace","path": "/spec/template/spec/containers/0/env/4/value","value": "99"}]'
```

## Exploring Prometheus

### Istio Mixer has built-in scraps at ports 42422 and 15014 
```
curl http://istio-telemetry.istio-system.svc.cluster.local:42422/metrics
```
### Use endpoint 15014 to monitor Mixer itself
```
curl http://istio-telemetry.istio-system.svc.cluster.local:15014/metrics
```

### Pilot generated metrics are visible at port 15014
```
curl http://istio-pilot.istio-system.svc.cluster.local:15014/metrics
```

### Policy generated metrics are visible at port 15014
```
curl http://istio-policy.istio-system.svc.cluster.local:15014/metrics
```
### Galley generated metrics are visible at port 15014
```
curl http://istio-galley.istio-system.svc.cluster.local:15014/metrics
```

## Sidecar proxy metrics
### Get dynamic configuration for productpage 
```
PRODUCTPAGE_POD=$(kubectl -n istio-lab get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')

kubectl -n istio-lab exec -i $PRODUCTPAGE_POD -c istio-proxy -- cat /etc/istio/proxy/envoy-rev0.json
```

### Scroll above and you will notice the listener port 15090 has route /stats/prometheus that Prometheus will scrape to get the data

### Run the curl command to scrape the Prometheus metrics

```
kubectl -n istio-lab exec -i $PRODUCTPAGE_POD -c istio-proxy -- curl http://localhost:15090/stats/prometheus
```

### Sidecar proxy stats can be seen at port 15000 on local loopback adapter
```
kubectl -n istio-lab exec -i $PRODUCTPAGE_POD -c istio-proxy -- curl http://localhost:15000/stats
```

### Check how many days are left for the certificates to expire
```
ALL_PODS=$(kubectl -n istio-lab get pods -o jsonpath='{.items..metadata.name}')

for pod in $ALL_PODS; do echo For pod $pod; kubectl -n istio-lab exec -i $pod -c istio-proxy -- curl -s http://localhost:15000/stats | grep server.days_until_first_cert_expiring; done
```

### Configuration for proxy can be seen through the proxy management port 15000 using config_dump route
```
kubectl -n istio-lab exec -i $PRODUCTPAGE_POD -c istio-proxy -- curl http://localhost:15000/config_dump
```

### Follow-up through the book on Web UI hands-on

## Clean-up 
```
cd ~/istio-$ISTIO_VERSION/install/kubernetes
kubectl -n istio-system delete -f istio-demo.yaml
kubectl delete ns istio-lab
```

