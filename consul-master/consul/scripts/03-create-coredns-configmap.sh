#!/bin/bash

echo create coredns config map to integrate consul dns with ICP coredns

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
      errors
      health
      kubernetes cluster.local in-addr.arpa ip6.arpa {
         pods insecure
         upstream
         fallthrough in-addr.arpa ip6.arpa
      }
      prometheus :9153
      proxy . /etc/resolv.conf
      cache 30
      reload
      loadbalance
    }
    consul {
      errors
      cache 30
      proxy . $(kubectl -n consul get svc consul-dns -o jsonpath='{.spec.clusterIP}')
    }
EOF
