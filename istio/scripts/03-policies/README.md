# Istio - Policy

## Commands used in Chapter 12 - Policy

### Change directory

```
cd ~/istio
cd scripts/03-policies
```

### Check if the current Istio environment is enabled for policy controls or not

```
kubectl -n istio-system get cm istio -o jsonpath="{@.data.mesh}" | grep disablePolicyChecks
```

## Enabling Rate Limits

### Create a quota

```
cat 01-create-quota-instance.yaml
kubectl -n istio-system apply -f 01-create-quota-instance.yaml
```

### Create QuotaSpec requestcount for requestcountquota instance

```
cat 02-create-quotaspec.yaml
kubectl -n istio-system apply -f 02-create-quotaspec.yaml
```

### Create QuotaSpecBinding using quota specification requestcount for productpage service

```
cat 03-create-quotaspecbinding.yaml
kubectl -n istio-system apply -f 03-create-quotaspecbinding.yaml
```

### Create the memquota handler that defines the quota limits
```
cat 04-create-memquota-handler.yaml
kubectl -n istio-system apply -f 04-create-memquota-handler.yaml
```

### Create quota rule and apply only to users who are not logged into the system
```
cat 05-create-quota-rule.yaml
kubectl -n istio-system apply -f 05-create-quota-rule.yaml
```

### Repeat curl to check RESOURCE_EXHAUST for enforcement of quota

```
rm -fr ~/.pki
curl -s --cacert $HOME/step/ca-chain.crt https://bookinfo.istio.io/productpage?[1-10] | grep RESOURCE
```

### Remove the override for productpage to limit 5 requests per second
```
cat 06-modify-memquota-handler.yaml
kubectl -n istio-system apply -f 06-modify-memquota-handler.yaml
```

## Controlling access to a service

### Modify the reviews virtual service to add a default route to reviews:v3 
### for all users except for user jason who will be directed to review:v2

```
cat 07-modify-reviews-virtual-service.yaml
kubectl -n istio-lab apply -f 07-modify-reviews-virtual-service.yaml
```

### If the logged-in user is jason, the ratings service will show reviews:v2 
### which will show black stars. If you logout as user jason, you should see red stars - 
### an indication that the routing rules based upon virtual service subsets are 
### working and the reviews:v3 is being called

## Deny Access

### Create a denier handler which will return status code 7 and message "not allowed"
```
cat 08-create-denier-handler.yaml
kubectl -n istio-system apply -f 08-create-denier-handler.yaml
```

### Create checknothing instance, which is nothing but a bridge between a handler and the rule.
```
cat 09-create-check-nothing-instance.yaml
kubectl -n istio-system apply -f 09-create-check-nothing-instance.yaml 
```

### Create a deny rule that denies the services where applicable and 
### implement it using checknothing instance (denyreviewsv3request) 
### through a deny handler (denyreviewsv3handler)
```
cat 10-create-denier-rule.yaml 
kubectl -n istio-system apply -f 10-create-denier-rule.yaml 
```

### Refresh https://bookinfo.istio.io/productpage
### Notice the message: Ratings service is currently not available. 
### On the contrary, if you log in as user jason, you will continue to see 
### black stars as that is not coming under the denier rule

### let's delete the denier rule for the next exercise for creating a white/blacklist
```
kubectl -n istio-system delete -f 10-create-denier-rule.yaml 

kubectl -n istio-system delete -f 09-create-check-nothing-instance.yaml

kubectl -n istio-system delete -f 08-create-denier-handler.yaml 
```

## Create attribute-based white/blacklist 

### Create a handler using listchecker
```
cat 11-create-listchecker-handler.yaml
kubectl -n istio-system apply -f 11-create-listchecker-handler.yaml
```

### Create an instance of listentry that will match with the labels version
```
cat 12-create-listentry-instance.yaml
kubectl -n istio-system apply -f 12-create-listentry-instance.yaml 
```

### Create rule using whitelist handler through an instance of listentry
```
cat 13-create-whitelist-rule.yaml
kubectl -n istio-system apply -f 13-create-whitelist-rule.yaml 
```

### Refresh https://bookinfo.istio.io/productpage and you should see Ratings unavailable without a user login.

## Creating IP based white/blacklist
### Configure Istio to accept or reject requests from a specific IP address or a subnet
```
cat 14-create-listchecker-handler.yaml
kubectl -n istio-system apply -f 14-create-listchecker-handler.yaml
```

### Create instance sourceip is created for the Mixer attribute of source.ip 
### of the request and if that is not present then allow access to all
```
cat 15-create-listentry-instance.yaml
kubectl -n istio-system apply -f 15-create-listentry-instance.yaml 
```

### Create a rule checkip that will use handler whitelistip to check source IP 
### for an incoming request at ingress gateway. If the source IP is from 10.57.0.0/16, 
### the request is denied.
```
kubectl -n istio-system apply -f 16-create-whitelist-rule.yaml 
```
### Refresh https://bookinfo.istio.io/productpage and you will see the message 
### PERMISSION_DENIED:whitelistip.istio-system:192.168.230.224 is not whitelisted

```
rm -fr ~/.pki
curl --cacert $HOME/step/ca-chain.crt https://bookinfo.istio.io/productpage
```

### Let's delete the rule, instance and handler for attribute and IP based white list 
### for the next lab exercise
```
kubectl -n istio-system delete -f 16-create-whitelist-rule.yaml 

kubectl -n istio-system delete -f 15-create-listentry-instance.yaml

kubectl -n istio-system delete -f 14-create-listchecker-handler.yaml

kubectl -n istio-system delete -f 13-create-whitelist-rule.yaml

kubectl -n istio-system delete -f 12-create-listentry-instance.yaml

kubectl -n istio-system delete -f 11-create-listchecker-handler.yaml 
```

### This concludes Istio - Policy

