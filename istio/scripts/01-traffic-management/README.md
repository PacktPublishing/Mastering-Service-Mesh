# Istio - Traffic Management

## Commands used in Chapter 10 - Traffic Management

### Get scripts from github

```
cd # Switch to home directory 
git clone https://github.com/servicemeshbook/istio
cd istio
git checkout $ISTIO_VERSION # Switch to branch version that we are using
```

### Switch to traffic-management directory

```
cd scripts/01-traffic-management
```

### Create Istio Gateway definition using ingress gateway

```
kubectl -n istio-system apply -f 00-create-gateway.yaml
```

### Find out Ingress gateway IP address

```
kubectl -n istio-system get svc istio-ingressgateway
```

### Find out Ingress host

```
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress..ip}') ; echo $INGRESS_HOST
```

### Test gateway - should resturn 404

```
curl -v http://$INGRESS_HOST
```

### Create a virtual service bookinfo that routes through above defined gateway

```
kubectl -n istio-system apply -f 01-create-virtual-service.yaml
```

### Test gateway - should resturn 200

```
curl -o /dev/null -s -w "%{http_code}\n" http://$INGRESS_HOST/productpage
```

### Check service endpoints - Kubernetes capabilities

```
kubectl -n istio-lab get ep | grep reviews
```

### Check pod IP addresses 

```
kubectl -n istio-lab get pods -o=custom-columns=NAME:.metadata.name,POD_IP:.status.podIP
```

### Check gateway and virtual service

```
kubectl -n istio-system get gateway
kubectl -n istio-system get vs
```

### Find pod's internal IP address

```
kubectl -n istio-lab get pods -o=custom-columns=NAME:.metadata.name,POD_IP:.status.podIP
```

### Find productpage pod IP address and test curl

```
export PRODUCTPAGE_POD=$(kubectl -n istio-lab get pods -l app=productpage -o jsonpath='{.items..status.podIP}') ; echo $PRODUCTPAGE_POD

curl -s http://$PRODUCTPAGE_POD:9080 | grep title
```

### Find cluster IP address - different than pod address

```
kubectl -n istio-lab get svc -o custom-columns=NAME:.metadata.name,CLUSTER_IP:.spec.clusterIP
```

### Find productpage IP address and run curl to test

```

PRODUCTPAGE_IP=$(kubectl -n istio-lab get svc -l app=productpage -o jsonpath='{.items...spec.clusterIP}') ; echo $PRODUCTPAGE_IP

curl -s http://$PRODUCTPAGE_IP:9080 | grep title
```

### Check product page end points

```
kubectl -n istio-lab get ep productpage
```

### Test DNS name resolution of the productpage

```
dig +short productpage.istio-lab.svc.cluster.local @10.96.0.10
```

### Edit productpage service to change clusterip to nodeport

```
kubectl -n istio-lab edit svc productpage
```

### Check services

```
kubectl -n istio-lab get svc productpage
```

### Find name of the VM or master node

```
kubectl get nodes
```

### Look at the reviews pods and examine the labels assigned to these pods

```
kubectl -n istio-lab get pods -l app=reviews --show-labels
```

### Create destination rules for all microservices within Bookinfo

```
kubectl -n istio-lab apply -f 02-create-destination-rules.yaml
```

## Traffic Shifting

### Create the virtual service which uses a subset defined through a destination rule

```
kubectl -n istio-lab apply -f 03-create-virtual-service-for-v1.yaml
```

### Identity Based Traffic Routing

### Modify the virtual service

```
kubectl -n istio-lab apply -f 04-identity-based-traffic-routing.yaml
```

### Browser based routing

```
kubectl -n istio-lab apply -f 05-chrome-browser-traffic-routing.yaml
```

## Canary deployment

### Modify the reviews virtual service with weight based routing

```
kubectl -n istio-lab apply -f 06-canary-deployment-weight-based-routing.yaml
```

### Run curl test 1000 times 
```
echo $INGRESS_HOST

time curl -s http://$INGRESS_HOST/productpage?[1-1000] | grep -c "full stars"
```

### Modify the reviews virtual service 
```
kubectl -n istio-lab apply -f 07-move-canary-to-production.yaml
```

### Run curl test 1000 times  

```
curl -s http://$INGRESS_HOST/productpage?[1-1000] | grep -c "full stars"
```

## Fault Injection

### Injecting http delay faults

### Inject a delay of 7 seconds for the end user jason for the ratings service:

```
kubectl -n istio-lab apply -f 08-inject-http-delay-fault.yaml
```

## Injecting http abort faults

### Modify the ratings virtual service to inject http abort for the test user jason

```
kubectl -n istio-lab apply -f 09-inject-http-abort-fault.yaml
```

## Requesting Timeouts

### Set the request timeout to 0.5 seconds for reviews service

```
kubectl -n istio-lab apply -f 10-set-request-timeout.yaml
```

### Introduce a 2 seconds latency between reviews and ratings service

```
kubectl -n istio-lab apply -f 11-inject-latency.yaml
```

### Remove the timeout and latency definitions from the virtual services before we begin circuit breaker testing

```
kubectl -n istio-lab delete -f 03-create-virtual-service-for-v1.yaml

kubectl -n istio-lab create -f 03-create-virtual-service-for-v1.yaml
```

## Circuit Breaker

### Implement the circuit breaker rules using destination rule for productpage

```
kubectl -n istio-lab apply -f 12-modify-productpage-destination-rule-for-circuit-breaker.yaml
```

### Install Istio Fortio testing tool

```
kubectl -n istio-lab apply -f 13-install-fortio-testing-tool.yaml
```

### Make sure that the Fortio is deployed properly

```
kubectl -n istio-lab get deploy fortio-deploy
```

### Check Istio proxy car is automatically injected in Fortio pod as shown by 2/2 

```
kubectl -n istio-lab get pods -l app=fortio
```

### Run a simple test that will not trigger any circuit breaker rule

### Make sure that there were no 5XX errors

```
export FORTIO_POD=$(kubectl -n istio-lab get pods -l app=fortio --no-headers -o custom-columns=NAME:.metadata.name) ; echo $FORTIO_POD

kubectl -n istio-lab exec -it $FORTIO_POD -c fortio /usr/bin/fortio -- load -c 1 -qps 0 -n 1 -loglevel Warning http://productpage:9080
```

### Change the number of concurrent connection to 3 (-c 3) and send 20 requests (-n 20) and run the test

```
kubectl -n istio-lab exec -it $FORTIO_POD -c fortio /usr/bin/fortio -- load -c 3 -qps 0 -n 20 -loglevel Warning http://productpage:9080
```

### Revert the destination rules for all services to their original state 

```
kubectl -n istio-lab apply -f 02-create-destination-rules.yaml
```

## Managing Traffic

### Managing Ingress Traffic Patterns

### Check external IP address of the ingress gateway.

```
kubectl -n istio-system get svc istio-ingressgateway -o custom-columns=Name:.metadata.name,EXTERNAL_IP:.status.loadBalancer.ingress[0].ip
```

### Create an entry in /etc/hosts file

```
export INGRESS_IP=$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}') ; echo $INGRESS_IP

if ! grep -q bookinfo.istio.io /etc/hosts ; then echo "$INGRESS_IP bookinfo.istio.io" | sudo tee -a /etc/hosts; fi
```

### Create bookinfo.istio.io virtual service

```
kubectl -n istio-system apply -f 14-create-bookinfo-virtual-service.yaml
```

### Test http://bookinfo.istio.io within the virtual machine

```
curl -s http://bookinfo.istio.io | grep title
```

## Managing Egress Traffic Patterns

### Command to find out the current outbound traffic policy mode

```
kubectl -n istio-system get cm istio -o yaml | grep -m1 -o "mode: ALLOW_ANY"
```

### Find out ratings pod IP address to test connectivity to an external service

```
export RATING_POD=$(kubectl -n istio-lab get pods -l app=ratings -o jsonpath='{.items..metadata.name}') ; echo $RATING_POD
```

### Run curl from ratings pod to test https://www.ibm.com and check the http code status

```
kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl -LI https://www.ibm.com | grep "HTTP/"

kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl -LI https://www.cnn.com | grep "HTTP/"
```

## Blocking Access to external services

### Change the config map for mode: ALLOW_ANY to mode: REGISTRY_ONLY

```
kubectl -n istio-system get cm istio -o yaml | sed 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/g' | kubectl replace -n istio-system -f -
```

### Check if mode: REGISTRY_ONLY has been set

```
kubectl -n istio-system get cm istio -o yaml | grep -m 1 -o "mode: REGISTRY_ONLY"
```

### Repeat curl test again for external services ibm.com


```
kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl -LI https://www.ibm.com | grep "HTTP/"
```

### Repeat curl test again for external services cnn.com

```
kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl -LI https://www.cnn.com | grep "HTTP/"
```

### Create a http ServiceEntry to allow access to http://httpbin.org

```
kubectl -n istio-lab apply -f 15-http-service-entry-for-httpbin.yaml
```

### ServiceEntry definition to allow https access to www.ibm.com

```
kubectl -n istio-lab apply -f 16-https-service-entry-for-ibm.yaml
```

### Wait couple of seconds and then use curl from ratings microservice to test external services for ibm

```
kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl -LI https://www.ibm.com | grep "HTTP/"
```

### Check for httpbin.org

```
RATING_POD=$(kubectl -n istio-lab get pods -l app=ratings -o jsonpath='{.items..metadata.name}') ; echo $RATING_POD

kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl http://httpbin.org/headers
```

### Check the istio-proxy logs 

```
kubectl -n istio-lab logs -c istio-proxy $RATING_POD | tail | grep curl
```

### Test https://www.ibm.com

```
kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl -LI https://www.ibm.com | grep "HTTP/"
```

### Check if we have access to https://www.cnn.com


```
kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl -LI https://www.cnn.com | grep "HTTP/"
```

## Routing rules for external services

### Add timeout rule 

```
kubectl -n istio-lab apply -f 17-add-timeout-for-httpbin-virtual-service.yaml
```

### Access httpbin.org and introduce a delay of 5 seconds and check if a timeout occurs from our end

```
time kubectl -n istio-lab exec -it -c ratings $RATING_POD -- curl -o /dev/null -s -w "%{http_code}\n" http://httpbin.org/delay/5
```

## Traffic Mirroring

### Deploy httpbin-v1

```
kubectl -n istio-lab apply -f 18-deploy-httpbin-v1.yaml
```

### Deploy httpbin-v2

```
kubectl -n istio-lab apply -f 19-deploy-httpbin-v2.yaml
```

### Deploy the httpbin service

```
kubectl -n istio-lab apply -f 20-create-kubernetes-httpbin-service.yaml
```

### Create destination rules to create subsets

```
kubectl -n istio-lab apply -f 21-create-destination-rules-subsets.yaml
```

### Create virtual service to direct 100% of traffic to subset v1

```
kubectl -n istio-lab apply -f 22-create-httpbin-virtual-service.yaml
```

### Use first command line window for httpbin:V1 tail

```
V1_POD=$(kubectl -n istio-lab get pod -l app=httpbin,version=v1 -o jsonpath={.items..metadata.name})

echo $V1_POD

kubectl -n istio-lab -c httpbin logs $V1_POD
```

### Use second command line window for httpbin:v2 tail

```
V2_POD=$(kubectl -n istio-lab get pod -l app=httpbin,version=v2 -o jsonpath={.items..metadata.name})

echo $V2_POD

kubectl -n istio-lab -c httpbin logs $V2_POD

```

### Open one more command line window and run the following curl command using ratings pod to send traffic to httpbin service

```
RATING_POD=$(kubectl -n istio-lab get pods -l app=ratings -o jsonpath='{.items..metadata.name}')

echo $RATING_POD

kubectl -n istio-lab exec -it $RATING_POD -c ratings -- curl http://httpbin:8000/headers | python -m json.tool
```

### Check tail of v1

```
kubectl -n istio-lab -c httpbin logs $V1_POD
```

### Check tail of v2
```
kubectl -n istio-lab -c httpbin logs $V2_POD
```

### Mirror traffic from v1 to v2

```
kubectl -n istio-lab apply -f 23-mirror-traffic-between-v1-and-v2.yaml
```

### Send same traffic to httpbin:v1 and we should see log line appear in both httpbin:v1 and httpbin:v2 pods

```
kubectl -n istio-lab exec -it $RATING_POD -c ratings -- curl http://httpbin:8000/headers | python -m json.tool
```

### httpbin:v1, shows one more line in addition the previous one that we had already received
```
kubectl -n istio-lab -c httpbin logs $V1_POD
```

### httpbin:v2, shows the new line

```
kubectl -n istio-lab -c httpbin logs $V2_POD
```
## Cleaning-up

### Change the mode from mode: REGISTRY_ONLY to mode: ALLOW_ANY for the purpose of next lab exercises

```
kubectl -n istio-system get cm istio -o yaml | sed 's/mode: REGISTRY_ONLY/mode: ALLOW_ANY/g' | kubectl replace -n istio-system -f -
```

### Double check if mode: ALLOW_ANY has been set
```
kubectl -n istio-system get cm istio -o yaml | grep -m 1 -o "mode: ALLOW_ANY"
```

### End of Istio Traffic management exercises 
