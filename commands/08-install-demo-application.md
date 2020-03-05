# Istio Demo Application 

## Chapter 8 - Install demo application

### Create a separate name space which will be used to deploy the application

```
kubectl create namespace istio-lab
```

### grant Cluster Admin role to the default service account in istio-lab namespace

```
kubectl create clusterrolebinding istio-lab-cluster-role-binding --clusterrole=cluster-admin --serviceaccount=istio-lab:default
```

### download bookinfo demo application YAML

```
mkdir -p ~/servicemesh
curl -L https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -o ~/servicemesh/bookinfo.yaml
```

### deploy the bookinfo application

```
kubectl -n istio-lab apply -f ~/servicemesh/bookinfo.yaml
```

### Check if Kubernetes services names are resolvable

```
dig +search +noall +answer kubernetes.default.svc.cluster.local
```

###  Check the status of the bookinfo application
```
kubectl -n istio-lab get pods
```

### Look at the Kubernetes service descriptions for Bookinfo application

```
kubectl -n istio-lab get svc
```

### Check the service description of the product page

```
kubectl -n istio-lab describe svc productpage
```

### Expand on all the running pods to get a closer look at the IP addresses and the node names

```
kubectl -n istio-lab get pods -o wide
```

### Get POD address and run curl command to get 200 status code

```
PRODUCTPAGE_IP=$(kubectl -n istio-lab get pods -l app=productpage -o jsonpath={.items..status.podIP}) ; echo $PRODUCTPAGE_IP
curl -o /dev/null -s -w "%{http_code}\n" http://$PRODUCTPAGE_IP:9080
```

### This concludes installing bookinfo application for learning Istio