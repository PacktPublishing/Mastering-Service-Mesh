# Linkerd - Commands 

Contents

- [Installing Linkerd](#Installing-Linkerd)
- [Reliability](#Reliability)
- [Security](#Security)
- [Visibility](#Visibility)

## Installing Linkerd

Copy and paste command as you practice.

### Command to list Linkerd releases so far

```
curl -Ls https://api.github.com/repos/linkerd/linkerd2/releases | grep tag_name
```

### To install Linkerd CLI in the VM environment

```
cd ## Switch to the home directory
export LINKERD2_VERSION=stable-2.6.0 
curl -s -L https://run.linkerd.io/install | sh - 
```

### Edit and source your local .bashrc and add linkerd2 to the path

```
vi ~/.bashrc

## Add these two lines

export LINKERD2_VERSION=stable-2.6.0
export PATH=$PATH:$HOME/.linkerd2/bin

source ~/.bashrc
echo $LINKERD2_VERSION
```

### Validate Linkerd client version
```
linkerd version
```

### Prerequisites required for installing Linkerd
```
linkerd check --pre
```

### Grant cluser_admin privilege to the service account default for the linkerd namespace
```
kubectl create clusterrolebinding linkerd-cluster-role-binding \
--clusterrole=cluster-admin --group=system:serviceaccounts:linkerd
```

### Run the linkerd install command
```
linkerd install | kubectl apply -f -
```


### Run linkerd check to make sure if an installation has succeeded or stuck at some step
```
linkerd check
```

### Run linkerd version to check the client and the server version
```
linkerd version
```

### Verify the Linkerd deployments
```
kubectl -n linkerd get deployments
```

### Verify the Linkerd services
```
kubectl -n linkerd get services
```

### Verify Linkerd pods
```
kubectl -n linkerd get pods
```

## Separation of Roles and Responsibilities

### Cluster Administrator

### To create objects that require cluster-admin role run
```
linkerd install config | kubectl apply -f -
```

### To validate the objects, run:
```
linkerd check config
```

### Application Administrator

### To install control pane run:

```
linkerd install control-plane | kubectl apply -f -
```

### Above failed since linkerd is already installed

### Accessing Linkerd Dashboard

```
cd ~/ # Switch to home directory
git clone https://github.com/servicemeshbook/linkerd.git
cd linkerd
git checkout $LINKERD2_VERSION
cd scripts
```

### Ingress Gateway

### We will now install nginx Ingress controller

```
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
helm install nginx-stable/nginx-ingress --name nginx --namespace kube-system \
--set fullnameOverride=nginx \
--set controller.name=nginx-controller \
--set controller.config.name=nginx-config \
--set controller.service.name=nginx-controller \
--set controller.serviceAccount.name=nginx
```

### Check the ingress controller service
```
kubectl -n kube-system get services -o wide -l app.kubernetes.io/instance=nginx
```
### Create an entry in /etc/hosts for the following host
```
export INGRESS_HOST=$(kubectl -n kube-system get service nginx-controller -o jsonpath='{.status.loadBalancer.ingress..ip}') ; echo $INGRESS_HOST

sudo sed -i '/dashboard.linkerd.local/d' /etc/hosts
echo "$INGRESS_HOST dashboard.linkerd.local" | sudo tee -a /etc/hosts
```

### Define an ingress rule to route traffic from dashboard.linkerd.local to Linkerd internal dashboard
```
cat 01-create-linkerd-ingress.yaml
kubectl -n linkerd apply -f 01-create-linkerd-ingress.yaml
```

### Check if the ingress is working
```
curl -s -H "Host: dashboard.linkerd.local" http://$INGRESS_HOST | grep -i title
```

### Installing Linkerd demo emoji app

### Grant grant cluster_admin role to emojivoto
```
kubectl create clusterrolebinding emojivoto-cluster-role-binding \
--clusterrole=cluster-admin --group=system:serviceaccounts:emojivoto
```

### Installing emojivoto application
```
curl -Ls https://run.linkerd.io/emojivoto.yml | kubectl apply -f -
```

### Check the application status
```
kubectl -n emojivoto get deployments,services,pods
```

### Create emojivoto.linked.local entry in /etc/hosts
```
export INGRESS_HOST=$(kubectl -n kube-system get service nginx-controller -o jsonpath='{.status.loadBalancer.ingress..ip}') ; echo $INGRESS_HOST
sudo sed -i '/emojivoto.linkerd.local/d' /etc/hosts
echo "$INGRESS_HOST emojivoto.linkerd.local" | sudo tee -a /etc/hosts
```

### Create emojivoto ingress rule
```
cat 02-create-emojivoto-ingress.yaml
kubectl -n emojivoto apply -f 02-create-emojivoto-ingress.yaml
```

### Check emojivoto app
```
curl -s -H "Host: emojivoto.linkerd.local" http://$INGRESS_HOST | grep -i title
```

### Inject linkerd sidecar proxy to the emoji application
```
kubectl get -n emojivoto deploy -o yaml | linkerd inject - | kubectl apply -f -
```

### let's check deployment, services, and pods
```
kubectl -n emojivoto get deployments
```

### We will check pods
```
kubectl -n emojivoto get pods
```

###  let's check services
```
kubectl -n emojivoto get services
```

### Installing booksapp application

### Admission webhook is enabled automatically when we installed a linkerd control plane
```
kubectl -n linkerd get deploy -l linkerd.io/control-plane-component=proxy-injector
```

### Grant cluster-admin role to linkerd-lab namespace
```
kubectl create clusterrolebinding linkerd-lab-cluster-role-binding \
--clusterrole=cluster-admin --serviceaccount=linkerd:default
```

### Create a namespace linkerd-lab
```
cat 03-create-namespace-sidecar-enabled-annotation.yaml
kubectl apply -f 03-create-namespace-sidecar-enabled-annotation.yaml
```

### Install booksapp microservice application from linkerd.io
```
curl -Ls https://run.linkerd.io/booksapp.yml | kubectl -n linkerd-lab apply -f -
```

### Check the network services.
```
kubectl -n linkerd-lab get svc
```

### Check the pod status of booksapp
```
kubectl -n linkerd-lab get pods
```

### Describe one of the pods above to see its contents
```
kubectl -n linkerd-lab describe pod -l app=authors
```

### Create booksapp.linked.local entry in /etc/hosts
```
sudo sed -i '/booksapp.linkerd.local/d' /etc/hosts
echo "$INGRESS_HOST booksapp.linkerd.local" | sudo tee -a /etc/hosts
```

### Create booksapp ingress rule
```
cat 04-create-booksapp-ingress.yaml
kubectl -n linkerd-lab apply -f 04-create-booksapp-ingress.yaml
```

### Check web app through curl
```
curl -s -H "Host: booksapp.linkerd.local" http://$INGRESS_HOST | grep -i /title
```

### End of Linkerd install and demo apps

## Reliability

### Change to scripts directory
```
cd ~/linkerd/scripts
```

### Scale voting and web deployments from 1 to 2 replicas

```
kubectl -n emojivoto scale deploy voting --replicas=2

kubectl -n emojivoto scale deploy web --replicas=2
```

### Check the stats on deployment using linkerd CLI
```
linkerd -n emojivoto stat deployments
```

### Check aggregated information at the pod level for each web and voting pods
```
linkerd -n emojivoto stat pods
```

### Now go to a browser locally or in the VM and run http://dashboard.linkerd.local

### linkerd top example - shows metrics from traffic to webapp microservice
```
linkerd top deployment/traffic --namespace linkerd-lab \
--to deployment/webapp --to-namespace linkerd-lab --path /books --hide-sources
```

### setting up a service profile

### validate if a service profile is deployed
```
kubectl -n linkerd-lab get crd | grep -i linkerd
```

### look at booksapp services
```
kubectl -n linkerd-lab get svc
```

### Look at the routes that Linkerd discovers
```
linkerd -n linkerd-lab routes services
```

### create a service profile using a linkerd profile command
```
linkerd profile --template webapp -n linkerd-lab > webapp.yaml
cat webapp.yaml
```

### Edit the generated template to match the one given below
```
cat 05-create-service-profile-web.yaml
```

### Deploy the above Service Profile for webapp service
```
kubectl -n linkerd-lab apply -f 05-create-service-profile-web.yaml
```

### let's see if the linkerd route command picks up the new additional routes
```
linkerd -n linkerd-lab routes services/webapp
```

### Following linkerd profile commands to see the generated profile
```
linkerd -n linkerd-lab profile --open-api webapp.swagger webapp

linkerd -n linkerd-lab profile --open-api authors.swagger authors

linkerd -n linkerd-lab profile --open-api books.swagger books
```

### let's create Linkerd Kubernetes primitive Service Profiles
```
linkerd -n linkerd-lab profile --open-api webapp.swagger webapp | kubectl -n linkerd-lab apply -f -

linkerd -n linkerd-lab profile --open-api books.swagger books| kubectl -n linkerd-lab apply -f -

linkerd -n linkerd-lab profile --open-api authors.swagger authors | kubectl -n linkerd-lab apply -f -
```

### Check the service profile definition created in linkerd-lab namespace
```
kubectl -n linkerd-lab get serviceprofile
```

### Let's check per route metrics accumulated from webapp service
```
linkerd -n linkerd-lab routes deploy/webapp
```

### Check per route metrics accumulated from authors service
```
linkerd -n linkerd-lab routes deploy/authors
```

### example shows traffic aggregation from webapp service to authors service
```
linkerd -n linkerd-lab routes deploy/webapp --to svc/authors
```

### traffic from webapp to books
```
linkerd -n linkerd-lab routes deploy/webapp --to svc/books
```

### Retries test

### Linkerd routes from books to authors and see the metrics
```
linkerd -n linkerd-lab routes deploy/books --to svc/authors
```

### edit the authors service profile 
### Add isRetryable: true for the route HEAD /authors/{id}.json
```
kubectl -n linkerd-lab patch sp authors.linkerd-lab.svc.cluster.local --type json --patch='[{"op": "add","path": "/spec/routes/4/isRetryable","value": true}]'
```

### Linkerd will begin the retry requests to this route automatically
```
linkerd -n linkerd-lab routes deploy/books --to svc/authors
```

### the failing request is showing a 100% success rate but notice the latency has increased due to the retry

### Retry budgets

### an example of a retry budget that can be specified at the service profile level
```
cat << EOT | tee
spec:
  retryBudget:
    retryRatio: 0.2
    minRetriesPerSecond: 10
    ttl: 10s
EOT
```

### Above shows the maximum time to live is 10 seconds and then the retry ratio is 20% of the total requests

### Timeouts

### Patch the service profile for authors.linkerd-lab.svc.cluster.local by adding line timeout: 25ms

```
kubectl -n linkerd-lab patch sp authors.linkerd-lab.svc.cluster.local \
--type json --patch='[{"op": "add","path": "/spec/routes/4/timeout","value": 25ms}]'
```

### Check patched service profile
```
kubectl -n linkerd-lab get sp authors.linkerd-lab.svc.cluster.local -o yaml
```

### Run linkerd route command to see the effect of timeout
```
linkerd -n linkerd-lab routes deploy/books --to svc/authors
```

### After a timeout is implemented, you will notice that the success rate has reduced from 100%

### Error code hunting

### Linkerd shows a tap command line with the argument which is very nice to watch without using the UI
```
linkerd tap deployment/web --namespace emojivoto \
--to deployment/voting --to-namespace emojivoto \
--path /emojivoto.v1.VotingService/VoteDoughnut
```

### End of Linkerd Reliability commands

## Security

### Change directory to scripts
```
cd ~/linkerd/scripts
``` 

### Validating mTLS on Linkerd

### Check the TLS status of traffic

### You will see live traffic from all existing deployments
```
linkerd tap deploy -n linkerd-lab
```

### Check the linkerd identity log
```
kubectl -n linkerd -c identity -l linkerd.io/control-plane-component=identity logs
```

### Using trusted certificates for control plane

### Using smallstep PKI to generate keys and certificates

### Add the helm repository to get the chart
```
helm repo add smallstep https://smallstep.github.io/helm-charts/
```

### check the helm repository list 
```
helm repo list
```

### Update helm repository with smallstep chart
```
helm repo update
```

### Install smallstep certificate through the newly added helm chart
```
helm install --name step --namespace step smallstep/step-certificates \
--set fullnameOverride="step" --set ca.db.enabled=false
```

### Check the status of step pods
```
kubectl -n step get pods
```

### Creating Step root and intermediate
```
kubectl -n step exec -t step-0 -- step certificate create --profile root-ca "My Root CA" root-ca.crt root-ca.key --no-password --insecure --force

kubectl -n step exec -t step-0 -- step certificate create identity.linkerd.cluster.local identity.crt identity.key --profile intermediate-ca --ca ./root-ca.crt --ca-key ./root-ca.key --no-password --insecure --force

```

### Check the expiry date of the intermediate certificate
```
kubectl -n step exec -t step-0 -- step certificate inspect identity.crt --short
```

### Extract certificates from the pod as we did not use a persistent volume while creating the step helm chart

```
kubectl -n step cp step-0:root-ca.crt /tmp/root-ca.crt

kubectl -n step cp step-0:identity.crt /tmp/identity.crt

kubectl -n step cp step-0:identity.key /tmp/identity.key
```

### Reinstall control plane to use our certificates

### Delete our current installation
```
linkerd install --ignore-cluster | kubectl delete -f -
```

### Create a new Linkerd installation using trusted certificates
```
linkerd install \
--identity-trust-anchors-file /tmp/root-ca.crt \
--identity-issuer-key-file /tmp/identity.key \
--identity-issuer-certificate-file /tmp/identity.crt \
--ignore-cluster | kubectl apply -f -
```
### Perform a linkerd check.
```
linkerd check
```

### Create the ingress definitions to access the dashboard
```
cd ~/linkerd/scripts
kubectl -n linkerd apply -f 01-create-linkerd-ingress.yaml
```

### Check the TLS status of traffic.
```
linkerd tap deploy -n linkerd
```

### The certificate expiry time is 24 hours for the leaf certificates that Linkerd identity CA

### Verify that by looking at the linkerd identity logs
```
kubectl -n linkerd -c identity -l linkerd.io/control-plane-component=identity logs
```

### Validate the leaf certificate, and the key is stored in linkerd-identity-issuer secret 
```
kubectl -n linkerd get secret linkerd-identity-issuer -o jsonpath='{.data.crt\.pem}' | base64 -d
```

### The output from above matches with /tmp/identity.crt
```
kubectl -n linkerd get secret linkerd-identity-issuer -o jsonpath='{.data.key\.pem}' | base64 -d
```

### Rotation of Identity certificates for microservices

### Steps to re-generate and rotate the identity certificates
```
kubectl -n step exec -t step-0 -- step certificate create identity.linkerd.cluster.local identity.crt identity.key --profile intermediate-ca --ca ./root-ca.crt --ca-key ./root-ca.key --no-password --insecure --force

kubectl -n step cp step-0:identity.crt /tmp/identity.crt

kubectl -n step cp step-0:identity.key /tmp/identity.key
```

### Delete the secret
```
kubectl -n linkerd delete secret linkerd-identity-issuer
```

### Re-create secret with a new certificate
```
kubectl -n linkerd create secret generic linkerd-identity-issuer \
 --from-file=crt.pem=/tmp/identity.crt \
 --from-file=key.pem=/tmp/identity.key
```

### Restart identity control plane deployments to pick the new certificate
```
kubectl -n linkerd rollout restart deploy linkerd-identity
```

### Check linkerd
```
linkerd check
```

### Check leaf certificates issued to control plane components by Linkerd
```
kubectl -n linkerd -c identity -l linkerd.io/control-plane-component=identity logs
```

### Secure Ingress Gateway

### TLS termination

### Create a leaf certificate for the booksapp.linkerd.local

```
kubectl -n step exec -t step-0 -- \
step certificate create booksapp.linkerd.local booksapp.crt booksapp.key \
--profile leaf --ca identity.crt --ca-key identity.key \
--no-password --insecure --force --kty=RSA --not-after=2160h

kubectl -n step cp step-0:booksapp.crt booksapp.crt
kubectl -n step cp step-0:booksapp.key booksapp.key
```

### Pass the certificate chain along with the leaf certificate private key to the Nginx Ingress Controller

### Create a certificate chain of leaf and intermediate

```
cat booksapp.crt /tmp/identity.crt  > ca-bundle.crt
```

### Create a Kubernetes TLS secret booksapp-keys. 
```
kubectl -n linkerd-lab create secret tls booksapp-keys --key booksapp.key --cert ca-bundle.crt
```

### Modify Ingress definition to include TLS secret
```
cat 07-create-booksapp-ingress-tls.yaml
kubectl -n linkerd-lab apply -f 07-create-booksapp-ingress-tls.yaml
```

### Find out the nginx pod name.

```
NGINX_POD=$(kubectl -n kube-system get pod -l app=nginx-controller -o jsonpath='{.items..metadata.name}') ; echo $NGINX_POD
```

### List the configurations pushed 
```
kubectl -n kube-system exec -it $NGINX_POD -- ls -l /etc/nginx/conf.d
```

### Check the configuration that was pushed
```
kubectl -n kube-system exec -it $NGINX_POD -- cat /etc/nginx/conf.d/linkerd-lab-booksapp.conf
```

### List TLS secrets
```
kubectl -n kube-system exec -it $NGINX_POD -- ls -l /etc/nginx/secrets
```

### Check secret that was just pushed - with certificate chain and private key
```
kubectl -n kube-system exec -it $NGINX_POD -- cat /etc/nginx/secrets/default
```

### Check https://booksinfo.linkerd.local from web browser

### Check TLS termination through curl

```
export INGRESS_PORT=$(kubectl -n kube-system get service nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].port}') ; echo $INGRESS_PORT

export INGRESS_HOST=$(kubectl -n kube-system get service nginx-controller -o jsonpath='{.status.loadBalancer.ingress..ip}') ; echo $INGRESS_HOST

rm -fr ~/.pki

curl -Ls -HHost:booksapp.linkerd.local \
--resolve booksapp.linkerd.local:$INGRESS_HOST:$INGRESS_PORT \
--cacert ca-bundle.crt https://booksapp.linkerd.local
```

### End of Linkerd Security commands

## Visibility

### Change directory 
```
cd ~/linkerd/scripts
```

### Gaining Insight into Service Mesh throup top command

```
linkerd top deployment --namespace emojivoto --hide-sources
```

### Create Prometheus Ingress rule to connect to Prometheus

```
cat 06-create-prometheus-ingress.yaml
kubectl -n linkerd apply -f 06-create-prometheus-ingress.yaml
```

### Create an entry in /etc/hosts for the prometheus.linkerd.local host.
```
export INGRESS_HOST=$(kubectl -n kube-system get service nginx-controller -o jsonpath='{.status.loadBalancer.ingress..ip}') ; echo $INGRESS_HOST

sudo sed -i '/prometheus.linkerd.local/d' /etc/hosts

echo "$INGRESS_HOST prometheus.linkerd.local" | sudo tee -a /etc/hosts
```

### Run http://prometheus.linkerd.local from your browser

### Test curl 

```
curl -Ls -H "Host: prometheus.linkerd.local" http://prometheus.linkerd.local | grep title
```

### External Prometheus integration

### Call federation API
```
curl -Ls -G --data-urlencode 'match[]={job="linkerd-proxy"}' --data-urlencode 'match[]={job="linkerd-controller"}' http://prometheus.linkerd.local/federate | tail -100
```

### Gather data directly from Linkerd proxies
```
export AUTHORS_PODIP=$(kubectl -n linkerd-lab get pods -l app=authors -o jsonpath='{.items[0].status.podIP}') ; echo $AUTHORS_PODIP

curl -s http://$AUTHORS_PODIP:4191/metrics | tail -100
```

### End of Linkerd Visibility commands
