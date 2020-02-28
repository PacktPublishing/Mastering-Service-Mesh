# Istio - Security

## Commands used in Chapter 11 - Security

### Change directory

```
cd ~/istio
git checkout $ISTIO_VERSION
cd scripts/02-security
```


### Test the httpbin service internally using http that outputs a teapot

```
curl http://httpbin.istio-lab.svc.cluster.local:8000/status/418
```

### Test the httpbin service internally using http that outputs an IP
```
curl http://httpbin.istio-lab.svc.cluster.local:8000/ip
```

### Find out the latest release of step cli

```
curl -s https://api.github.com/repos/smallstep/cli/releases/latest | grep tag_name
```

### We will download v0.10.1 version

```
cd ~/

curl -LOs https://github.com/smallstep/cli/releases/download/v0.13.3/step_0.13.3_linux_amd64.tar.gz
```

### Extract and copy the Step cli to /bin

```
tar xvfz step_0.13.3_linux_amd64.tar.gz

sudo mv step_0.13.3/bin/step /bin
```

### Create a directory and create a root certificate using root --profile through step command

```
mkdir -p ~/step

cd ~/step

step certificate create --profile root-ca "My Root CA" root-ca.crt root-ca.key
```

### To establish a chain of trust, let's create an intermediate CA

```
step certificate create istio.io istio.crt istio.key --profile intermediate-ca --ca ./root-ca.crt --ca-key ./root-ca.key

```

### Create X.509 certificate for httpbin.istio.io

```
step certificate create httpbin.istio.io httpbin.crt httpbin.key --profile leaf --ca istio.crt --ca-key istio.key --no-password --insecure --not-after 2160h
```

### Create X.509 certificate for bookinfo.istio.io

```
step certificate create bookinfo.istio.io bookinfo.crt bookinfo.key --profile leaf --ca istio.crt --ca-key istio.key --no-password --insecure --not-after 2160h
```

### Verifying and inspect certificates

```
step certificate inspect bookinfo.crt --short
```

### For the verification to be ok, the return code should be 0

```
step certificate verify bookinfo.crt -roots istio.crt

echo $? 
```

## Mapping IP address to hostname

### Find out the external IP address of the Istio ingress gateway

```
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}') ; echo $INGRESS_PORT

export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress..ip}') ; echo $INGRESS_HOST
```

### Update the /etc/hosts file

```
if ! grep -q bookinfo.istio.io /etc/hosts ; then echo "$INGRESS_HOST bookinfo.istio.io bookinfo" | sudo tee -a /etc/hosts; fi

if ! grep -q httpbin.istio.io /etc/hosts ; then echo "$INGRESS_HOST httpbin.istio.io httpbin" | sudo tee -a /etc/hosts; fi

cat /etc/hosts
```

### Ping both hosts to make sure that IP address is resolved

```
ping -c4 bookinfo.istio.io

ping -c4 httpbin.istio.io
```

### Add the ingress-sds container to the Istio Ingress gateway

```
kubectl -n istio-system get deploy istio-ingressgateway -o yaml > ~/servicemesh/istio-ingressgateway-non-sds.yaml

cd ~/istio-$ISTIO_VERSION

helm template install/kubernetes/helm/istio/ --name istio \
 --namespace istio-system \
 -x charts/gateways/templates/deployment.yaml \
 --set gateways.istio-egressgateway.enabled=false \
 --set gateways.istio-ingressgateway.sds.enabled=true \
 | kubectl apply -f -
```

### Check the logs from the ingress-sds container of the Istio Ingress Gateway

```
kubectl -n istio-system logs -l app=istio-ingressgateway -c ingress-sds
```

### Check the logs from istio-proxy which was injected for Secret Service Discovery
```
kubectl -n istio-system logs -l app=istio-ingressgateway -c istio-proxy 
```

### After making sure that SDS is enabled, next we go through a simple process to create certificates and keys
### Create secrets for the domain httpbin.istio.io and bookinfo.istio.io

```
kubectl -n istio-system create secret generic httpbin-keys --from-file=key=$HOME/step/httpbin.key --from-file=cert=$HOME/step/httpbin.crt 

kubectl -n istio-system create secret generic bookinfo-keys --from-file=key=$HOME/step/bookinfo.key --from-file=cert=$HOME/step/bookinfo.crt
```

### Add hosts httpbin.istio.io and bookinfo.istio.io to our existing Istio mygateway


```
cat 01-add-bookinfo-https-to-mygateway.yaml
kubectl -n istio-system apply -f 01-add-bookinfo-https-to-mygateway.yaml
```

### Check the log again in ingress-sds container of the Istio Ingress Gateway
```
kubectl -n istio-system logs -l app=istio-ingressgateway -c ingress-sds
```

### [Optional step] only if above is not successful.

```
export INGRESS_GW=$(kubectl -n istio-system get pods -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}') ; echo $INGRESS_GW

kubectl -n istio-system delete pod $INGRESS_GW
```

### Create a virtual service for httpbin.istio.io to route the traffic for httpbin requests

```
cat 02-create-virtual-service-for-httpbin.yaml
kubectl -n istio-system apply -f 02-create-virtual-service-for-httpbin.yaml
```

### Use the curl command to send the request using hostname by setting the header, using the resolve parameter to set the IP address and set cacert parameter

```
rm -fr ~/.pki ## Reset local NSS database

curl -HHost:httpbin.istio.io --resolve httpbin.istio.io:$INGRESS_PORT:$INGRESS_HOST --cacert $HOME/step/istio.crt https://httpbin.istio.io/status/418

curl -HHost:httpbin.istio.io --resolve httpbin.istio.io:$INGRESS_PORT:$INGRESS_HOST --cacert $HOME/step/istio.crt https://httpbin.istio.io/ip
```

### Check the TLS implementation

```
HTTPBIN=$(kubectl -n istio-lab get pods -l app=httpbin -o jsonpath={.items[0].metadata.name}) ; echo $HTTPBIN 

istioctl authn tls-check $HTTPBIN.istio-lab httpbin.istio-lab.svc.cluster.local 
```

### Check meshpolicies

```
kubectl get meshpolicies default -o yaml
```

### We will enable simple TLS for bookinfo application

```
cat 03-create-virtual-service-for-bookinfo.yaml
kubectl -n istio-system apply -f 03-create-virtual-service-for-bookinfo.yaml 
```

### Check http access and https access for bookinfo.istio.io
```
curl -s http://bookinfo.istio.io | grep title

curl -s --cacert $HOME/step/istio.crt https://bookinfo.istio.io  | grep title

```

## Rotating Virtual Service keys and certificates

### Let's check the certificate that we issued to httpbin

```
cd ~/step

step certificate inspect httpbin.crt --short
```

### Delete the httpbin-keys secret as we will create a new set of keys

```
kubectl -n istio-system delete secret httpbin-keys 
```

### Regenerate key and certificate for httpbin.istio.io and bundle intermediate CA

```
step certificate create httpbin.istio.io httpbin.crt httpbin.key --profile leaf --ca istio.crt --ca-key istio.key --no-password --insecure --not-after 2160h
```

### Create a secret for httpbin using new key and certificate

```
kubectl -n istio-system create secret generic httpbin-keys --from-file=key=$HOME/step/httpbin.key --from-file=cert=$HOME/step/httpbin.crt 
```

### Check the SDS log entry for the certificate that we created
```
kubectl -n istio-system logs -l app=istio-ingressgateway -c ingress-sds
```
### Run the same curl test against httpbin.istio.io

```
curl -HHost:httpbin.istio.io --resolve httpbin.istio.io:$INGRESS_PORT:$INGRESS_HOST --cacert $HOME/step/istio.crt https://httpbin.istio.io/ip
```

## Enabling Ingress Gateway for httpbin using mutual TLS

### Create client certificate and key using RSA that will be used by client 

```
step certificate create httpbin.istio.io client.crt client.key --profile leaf --ca istio.crt --ca-key istio.key --no-password --insecure --kty RSA --size 2048
```

### Create a chain of certificates from root-ca and intermediate authority

```
step certificate bundle root-ca.crt istio.crt ca-chain.crt
```

### Recreate the httpbin-keys secret using one additional parameter cacert

```
kubectl -n istio-system delete secret httpbin-keys


kubectl -n istio-system create secret generic httpbin-keys --from-file=key=$HOME/step/httpbin.key --from-file=cert=$HOME/step/httpbin.crt --from-file=cacert=$HOME/step/ca-chain.crt
```

### Modify gateway definition to change TLS mode from SIMPLE to MUTUAL

```
cd ~/istio/scripts/02-security/
cat 04-add-mutual-TLS-to-bookinfo-https-to-mygateway.yaml
kubectl -n istio-system apply -f 04-add-mutual-TLS-to-bookinfo-https-to-mygateway.yaml
```

## Verify TLS configuration

### Check the TLS flow between server and client. 

```
HTTPBIN=$(kubectl -n istio-lab get pods -l app=httpbin -o jsonpath={.items[0].metadata.name}) ; echo $HTTPBIN

istioctl authn tls-check $HTTPBIN.istio-lab istio-ingressgateway.istio-system.svc.cluster.local
```

### Modify the curl command to pass client cert and key parameters in addition to cacert

```
curl -HHost:httpbin.istio.io --resolve httpbin.istio.io:$INGRESS_PORT:$INGRESS_HOST --cacert $HOME/step/ca-chain.crt --cert $HOME/step/client.crt --key $HOME/step/client.key https://httpbin.istio.io/status/418
```

### Check the TLS settings between Bookinfo productpage

```
PRODUCT_PAGE=$(kubectl -n istio-lab get pods -l app=productpage -o jsonpath={.items..metadata.name}) ; echo $PRODUCT_PAGE

istioctl authn tls-check $PRODUCT_PAGE.istio-lab istio-ingressgateway.istio-system.svc.cluster.local
```

## Enabling Mutual TLS within the mesh

### Check mesh policies

```
kubectl get meshpolicies default -o yaml
```

### Check mode ISTIO_MUTUAL
```
cat 05-create-mtls-bookinfo-destination-rules.yaml 
```
### Apply modified destination rules for bookinfo microservices
```
kubectl -n istio-lab apply -f 05-create-mtls-bookinfo-destination-rules.yaml 
```

### Check the TLS between services
```
istioctl authn tls-check $PRODUCT_PAGE.istio-lab istio-ingressgateway.istio-system.svc.cluster.local

istioctl authn tls-check $PRODUCT_PAGE.istio-lab productpage.istio-lab.svc.cluster.local
```

### The above result shows that traffic between microservices is mTLS
### But, traffic at Ingress gateway can be either HTTP or HTTPS due to our definition 
### of a SIMPLE TLS while defining gateway for bookinfo.istio.io host

### Redefine and apply destination rule for httpbin
```
cat 06-create-mtls-httpbin-destination-rules.yaml
kubectl -n istio-lab apply -f 06-create-mtls-httpbin-destination-rules.yaml 
```

### Check headers for additional header for secure identity
```
curl http://httpbin.istio.io/headers
```

### Check above URI=spiffe for secure identity

### Enabling mTLS at the namespace level
```
cat 07-create-mtls-for-istio-lab-namespace.yaml 
kubectl -n istio-lab apply -f 07-create-mtls-for-istio-lab-namespace.yaml 
```

### Verifying TLS Configuration
```
export RATING_POD=$(kubectl -n istio-lab get pods -l app=ratings -o jsonpath='{.items[0].metadata.name}') ; echo $RATING_POD

istioctl authn tls-check $RATING_POD.istio-lab ratings.istio-lab.svc.cluster.local
```

### Notice above that the server and client communication between microservices is mTLS

### Disable mTLS between Istio services and Kubernetes API server
```
cat 08-disable-mtls-for-kube-apiserver.yaml
kubectl -n istio-system apply -f 08-disable-mtls-for-kube-apiserver.yaml
```

### Run curl with cacert, key and cert parameters for mTLS to work for httpbin
```
curl -HHost:httpbin.istio.io --resolve httpbin.istio.io:$INGRESS_PORT:$INGRESS_HOST --cacert $HOME/step/ca-chain.crt --cert $HOME/step/client.crt --key $HOME/step/client.key https://httpbin.istio.io/status/418

```

### Enable mTLS for browser - additional steps

### Install certutil and pk12util utilities available
```
# yum -y install nss-tools
```

### Import the root certificate in nss database
```
certutil -d sql:$HOME/.pki/nssdb -A -n httpbin.istio.io -i $HOME/step/root-ca.crt -t "TC,,"
```

### Create a client bundle using the client's key and a certificate in pk12 format
```
openssl pkcs12 -export -clcerts  -inkey $HOME/step/client.key -in $HOME/step/client.crt -out httpbin.istio.io.p12 -passout pass:password -name "Key pair for httpbin.istio.io"
```

### Import the client key bundle into nss database using pk12util
```
pk12util -i httpbin.istio.io.p12 -d sql:$HOME/.pki/nssdb -W password
```

### List certificates in nss database
```
certutil -d sql:$HOME/.pki/nssdb -L
```

### Run https://httpbin.istio.io/ip from the Chrome browser and a pop-up will show to 
### choose the certificate to authenticate to httpbin.istio.io and select httpbin.istio.io and now you can see the output.

## Authorization

### First lets switch to subset v2 of reviews virtual service so that it shows black stars in the ratings

```
kubectl -n istio-lab patch vs reviews --type json -p '[{"op":"replace","path":"/spec/http/0/route/0/destination/subset","value": "v2"}]'

kubectl -n istio-lab get vs reviews -o yaml | grep -B1 subset:
```

### Create the ClusterRbacConfig for the istio-lab namespace
```
cat 09-create-clusterrbac-config.yaml
kubectl -n istio-lab apply -f 09-create-clusterrbac-config.yaml
```

### Point your browser to https://httpbin.istio.io/productpage and you should see a message RBAC: access denied

## Namespace level authorization

### Create ServiceRole definition in which GET access to bookinfo services is available to all services
```
cat 10-create-service-role.yaml
kubectl -n istio-lab apply -f 10-create-service-role.yaml
```

### Define the ServiceRoleBinding.
```
cat 11-create-service-role-binding.yaml
kubectl -n istio-lab apply -f 11-create-service-role-binding.yaml
```
### Run https://bookinfo.istio.io in your browser and you should be able to see the page

## Service Level Authorization

### delete the ServiceRole and ServiceRoleBinding that we just did in the previous section.
```
kubectl -n istio-lab delete -f 11-create-service-role-binding.yaml

kubectl -n istio-lab delete -f 10-create-service-role.yaml
```

### Create a ServiceRole to create an access rule only for GET method for the productpage service

```
cat 12-create-service-role-productpage.yaml
kubectl -n istio-lab apply -f 12-create-service-role-productpage.yaml
```

### Create a ServiceRoleBinding allowing access to all users through ServiceRole productpage-viewer authorization
```
cat 13-create-service-role-binding-productpage.yaml
kubectl -n istio-lab apply -f 13-create-service-role-binding-productpage.yaml
```

### Create ServiceRole rules for details and reviews
```
cat 14-create-service-role-details-reviews.yaml
kubectl -n istio-lab apply -f 14-create-service-role-details-reviews.yaml
```
### service accounts for each microservice were created at the time of installation of the bookinfo application
```
kubectl -n istio-lab get sa
```

### Grant ServiceRoleBinding to a service account of productpage
```
cat kubectl -n istio-lab apply -f 16-apply-service-role-binding-details-reviews.yaml
kubectl -n istio-lab apply -f kubectl -n istio-lab apply -f 16-apply-service-role-binding-details-reviews.yaml
```

### Check istioctl auth validate command
```
istioctl experimental auth validate -f 17-create-service-role-ratings.yaml,18-create-service-role-binding-ratings.yaml
```

###  Point your browser to https://bookinfo.istio.io/productpage and you should see the Book Details and Book Reviews sections 

### Fix Ratings service is currently unavailable by creating a service role for ratings service using GET
```
kubectl -n istio-lab create sa bookinfo-productpage
```

### Create ServiceRoleBinding ratings-viewer
```
cat 17-create-service-role-ratings.yaml
kubectl -n istio-lab apply -f 17-create-service-role-ratings.yaml 
```

### Create ServiceRoleBinding bind-ratings-viewer
```
cat 18-create-service-role-binding-ratings.yaml
kubectl -n istio-lab apply -f 18-create-service-role-binding-ratings.yaml 
```

### Refresh your web page and you will see ratings service working now showing black stars

## Service Level Authorization for Databases

### Create a service account bookinfo-ratings-v2 and ratings-v2 deployment
```
cat 19-create-sa-ratings-v2.yaml 
kubectl -n istio-lab apply -f 19-create-sa-ratings-v2.yaml 
```

### To route traffic to version v2 of the ratings service, we will patch existing ratings virtual service 
### so that it uses the subset v2 of ratings service
```
kubectl -n istio-lab patch vs ratings --type json -p '[{"op":"replace","path":"/spec/http/0/route/0/destination/subset","value": "v2"}]'
```

### Confirm if this was set properly
```
kubectl -n istio-lab get vs ratings -o yaml | grep -B1 subset:
```

### Create mongodb service and mongodb-v1 deployment
```
cat 20-deploy-mongodb-service.yaml 
kubectl -n istio-lab apply -f 20-deploy-mongodb-service.yaml 
```

### Wait for the mongodb pods to  be ready - check
```
kubectl -n istio-lab get pods -l app=mongodb
```

### Create ServiceRole for MongoDB
```
cat 21-create-service-role-mongodb.yaml 
kubectl -n istio-lab apply -f 21-create-service-role-mongodb.yaml 
```

### Create ServiceRoleBinding bind-mongodb-viewer
```
cat 22-create-service-role-binding-mongodb.yaml
kubectl -n istio-lab apply -f 22-create-service-role-binding-mongodb.yaml 
```

### Find out the ratings v2 pod name
```
export RATINGS_POD=$(kubectl -n istio-lab get pods -l app=ratings -o jsonpath='{.items[0].metadata.name}') ; echo $RATINGS_POD
```

### Check mTLS conflict between ratings-v2 pod and the mongodb service
```
istioctl authn tls-check $RATINGS_POD.istio-lab mongodb.istio-lab.svc.cluster.local
```

### Create the destination rule and wait for few seconds for the rule to propagate

```
cat 23-create-mongodb-destination-rule.yaml
kubectl -n istio-lab apply -f 23-create-mongodb-destination-rule.yaml
```

### Check for any mTLS conflict if any - wait for few seconds
```
istioctl authn tls-check $RATINGS_POD.istio-lab mongodb.istio-lab.svc.cluster.local
```

### Run this command to change the ratings from 5 to 1 and 4 to 3
```
export MONGO_POD=$(kubectl -n istio-lab get pod -l app=mongodb -o jsonpath='{.items..metadata.name}') ; echo $MONGO_POD

cat << EOF | kubectl -n istio-lab exec -i -c mongodb $MONGO_POD -- mongo
use test
db.ratings.find().pretty()
db.ratings.update({"rating": 5},{\$set:{"rating":1}})
db.ratings.update({"rating": 4},{\$set:{"rating":3}})
db.ratings.find().pretty()
exit
EOF
```

### Create ServiceRole and ServiceRoleBinding to httpbin service so that we can use the same service in later chapters
```
cat 24-create-service-role-binding-httpbin.yaml
kubectl -n istio-lab apply -f 24-create-service-role-binding-httpbin.yaml
```

### Refresh the page and you can see the ratings change from 4 to 3 and 5 to 1.

### Delete role-based access control for the next chapter and patch ratings service back to v1.

```
kubectl -n istio-lab delete -f 09-create-clusterrbac-config.yaml

kubectl -n istio-lab patch vs ratings --type json -p '[{"op":"replace","path":"/spec/http/0/route/0/destination/subset","value": "v1"}]'
```

### This concludes the security implementation in Istio