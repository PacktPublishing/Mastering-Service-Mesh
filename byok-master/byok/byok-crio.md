# Build your own Kubernetes cluster in a single VM using CRI-O

This guide is based upon an [article](https://kubevirt.io/2019/KubeVirt_k8s_crio_from_scratch.html) written by `Pedro Ibáñez Requena`

## Prerequisites - Download base VM

Use one of the two option below to download your base VM image and start the VM.

* Windows - Read through [this](Windows/)
* MacBook - Read through [this](MacBook/) 


## In base VM

The `root` password in the VM is `password`. When you start VM, it will automatically login as `user` and the password is `password` for the user `user`.

Login as root.

```
sudo su -
yum -y update
```

Note: You can copy and paste command from here to the VM. You can use middle mouse button to paste the commands from the clipboard or press `Shift-Ctrl-V` to paste the contents from the clipboard to the command line shell.

## Prerequisites

* Install `socat` - For Helm, `socat` is used to set the port forwarding for both the Helm client and Tiller.
    ```
    yum -y install socat
    ```
* Set `SELINUX=disabled` in `/etc/selinux/config` and reboot for this to take effect. After reboot, you should get output from `getenforce` as `disabled`.
    ```
    # getenforce
    Disabled
    ```

## Build Kubernetes using CRI-O

## Install CRI-O

Build CRI-O from source

Add kernel modules

```
modprobe br_netfilter
echo br_netfilter > /etc/modules-load.d/br_netfilter.conf
modprobe overlay
echo overlay > /etc/modules-load.d/overlay.conf
```

Disable `selinux`
```
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

Install required packages to build cri-o from source

```
yum install btrfs-progs-devel container-selinux device-mapper-devel gcc git glib2-devel glibc-devel glibc-static gpgme-devel json-glib-devel libassuan-devel libgpg-error-devel libseccomp-devel make pkgconfig skopeo-containers tar wget -y

yum install golang-github-cpuguy83-go-md2man golang -y
```

Create directories
```
for d in "/usr/local/go /etc/systemd/system/kubelet.service.d/ /var/lib/etcd /etc/cni/net.d /etc/containers"; do mkdir -p $d; done
```

Clone runc, cri-o, cni and conmon repos
```
git clone https://github.com/opencontainers/runc /root/src/github.com/opencontainers/runc
git clone https://github.com/cri-o/cri-o /root/src/github.com/cri-o/cri-o
git clone https://github.com/containernetworking/plugins /root/src/github.com/containernetworking/plugins
git clone http://github.com/containers/conmon /root/src/github.com/conmon
```

Build runc
```
cd /root/src/github.com/opencontainers/runc
export GOPATH=/root
make BUILDTAGS="seccomp selinux"
make install
ln -sf /usr/local/sbin/runc /usr/bin/runc
```

Build cri-o
```
export GOPATH=/root
export GOBIN=/usr/local/go/bin
export PATH=/usr/local/go/bin:$PATH
cd /root/src/github.com/cri-o/cri-o
git checkout release-1.16
make
make install
make install.systemd
make install.config
```

Build conmon for cri-o container monitoring
```
cd /root/src/github.com/conmon
make
make install
```

Build cni plugin
```
cd /root/src/github.com/containernetworking/plugins
./build_linux.sh
mkdir -p /opt/cni/bin
cp bin/* /opt/cni/bin/
```

Make sure that `cgroup_manager` is set to `cgroupfs` in `/etc/crio/crio.conf`
```
sed -i 's/cgroup_manager =.*/cgroup_manager = "cgroupfs"/g' /etc/crio/crio.conf
grep cgroup_manager /etc/crio/crio.conf
```

Make sure that `storage_driver` is set to `overlay2`
```
sed -i 's/#storage_driver =.*/storage_driver = "overlay2"/g' /etc/crio/crio.conf
grep storage_driver /etc/crio/crio.conf
```

Edit `/etc/crio/crio.conf` and uncomment `storage_option` and make it `storage_option = [ "overlay2.override_kernel_check=1" ]` 

Delete line after `storage_option` option
```
sed -ie '/#storage_option =/{n;d}' /etc/crio/crio.conf
```
Uncomment and add the value
```
sed -i 's/#storage_option =.*/storage_option = [ "overlay2.override_kernel_check=1" ]/g' /etc/crio/crio.conf
grep storage_option /etc/crio/crio.conf
```

Change `network_dir` to `/etc/crio/net.d` since `kubeadm reset` empties `/etc/cni/net.d`
```
sed -i 's~network_dir =.*~network_dir = "/etc/crio/net.d/"~g' /etc/crio/crio.conf
grep network_dir /etc/crio/crio.conf
```

Create entries in `/etc/crio/net.d`
```
mkdir -p /etc/crio/net.d
cd /etc/crio/net.d/
wget https://raw.githubusercontent.com/cri-o/cri-o/master/contrib/cni/10-crio-bridge.conf
```

Get the policy.json file
```
cat << EOF > /etc/containers/policy.json
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ],
    "transports": {
        "docker": {}
    }
}
EOF
```

Add extra params to `kubelet` service
```
cat << EOF > /etc/default/kubelet
KUBELET_EXTRA_ARGS=--feature-gates="AllAlpha=false,RunAsGroup=true" --container-runtime=remote --cgroup-driver=cgroupfs --container-runtime-endpoint='unix:///var/run/crio/crio.sock' --runtime-request-timeout=5m
EOF
```

Reload systemd daemon
```
systemctl daemon-reload
```

Enable and start crio
```
systemctl enable crio
systemctl start crio
systemctl status crio
```


Version of CRI-O

```
# crio --version
crio version 1.16.0
commit: "40fa905d9d4ad1a4a73f7a3cc512669d06bd184e-dirty"
```

Install cri-tools (Make sure to download corresponding version)

```
VERSION="v1.16.0"
curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-${VERSION}-linux-amd64.tar.gz --output crictl-${VERSION}-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz
```

Version of crictl
```
# crictl --version

crictl version v1.16.0
```

## Build Kubernetes using one VM

We will use the same version for Kubernetes as we used for crio

### iptables for Kubernetes

```
# Configure iptables for Kubernetes
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
EOF
sysctl --system
```

### Add Kubernetes repo

```
cat << EOF >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

rpm --import https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
```

### Install Kubernetes 

Check available versions of packages

```
yum --showduplicates list kubeadm
```

For example, we will be selecting `1.16.2-0`.

```
version=1.16.2-0
yum install -y kubelet-$version kubeadm-$version kubectl-$version
```

Restart crio and enable kubelet
```
systemctl restart crio
systemctl enable --now kubelet
```

#### Disable firewalld

```
systemctl disable firewalld
systemctl stop firewalld
```

If you do not want to disable firewall, you may need to open ports through the firewall. For Kubernetes, open the following.

```
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --zone=public --add-port=6443/tcp --permanent
firewall-cmd --zone=public --add-port=10250/tcp --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --reload
```

#### Disable swap

Kuberenets does not like swap to be on.

```
swapoff -a
```

Comment entry for swap in `/etc/fstab`. Example:

```
#/dev/mapper/centos-swap swap                    swap    defaults        0 0
```

### Run kubeadm

We will use same CIDR as it is defined in the CRI-O.

```
# cat /etc/crio/net.d/10-crio-bridge.conf | grep subnet
        "subnet": "10.88.0.0/16",
```


Check by running `visudo` and there must be an entry `user  ALL=(ALL)       NOPASSWD: ALL` so that the user `user` has `sudo` authority to type `root` commands without requiring a password.
Type `exit` to logout from root.

```
# exit
```

```
sudo kubeadm config images pull
sudo kubeadm init --pod-network-cidr=10.88.0.0/16
```

The output is as shown:

```
<< removed >>
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.142.101:6443 --token 2u0en7.g1igrb2w54g9bts7 \
    --discovery-token-ca-cert-hash sha256:cae7cae0274175d680a683e464e2b5e6e82817dab32c4b476ba9a322434227bb 
```

If you loose above `kubeadm join` command, a new token and hash can be generated as:

```
# kubeadm token create --print-join-command
kubeadm join 192.168.142.101:6443 --token 1denfs.nw73pkobgksk0ej9     --discovery-token-ca-cert-hash sha256:cae7cae0274175d680a683e464e2b5e6e82817dab32c4b476ba9a322434227bb
```

Since we will be using a single VM, the Kubernetes token from above is for reference purpose only. You will require the above token command in you require a multi-node Kubernetes cluster.

### Configure kubectl

Run the following command as `user` and `root` to configure `kubectl` command line CLI tool to communicate with the Kubernetes environment.

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Check Kubernetes version

```
$ kubectl version --short
Client Version: v1.16.2
Server Version: v1.16.2
```

Untaint the node - this is required since we have only one VM to install objects.

```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

Check node status

```
$ kubectl get nodes
NAME            STATUS   ROLES    AGE   VERSION
okd.zinox.com   Ready    master   15m   v1.16.2
```

Check pod status in `kube-system` and you will notice that `coredns` pods are in pending state since pod network has not yet been installed.

```
$ $ kubectl get pods -A
NAMESPACE     NAME                                    READY   STATUS    RESTARTS   AGE
kube-system   coredns-5644d7b6d9-6s25d                1/1     Running   0          15m
kube-system   coredns-5644d7b6d9-9m5gt                1/1     Running   0          15m
kube-system   etcd-okd.zinox.com                      1/1     Running   0          14m
kube-system   kube-apiserver-okd.zinox.com            1/1     Running   0          14m
kube-system   kube-controller-manager-okd.zinox.com   1/1     Running   0          14m
kube-system   kube-proxy-zlngl                        1/1     Running   0          15m
kube-system   kube-scheduler-okd.zinox.com            1/1     Running   0          14m
```

## Install Calico network for pods

Choose proper version of Calico [Link](https://docs.projectcalico.org/v3.10/getting-started/kubernetes/requirements)

Calico 3.10 is tested with Kubernetes versions 1.14, 1.15 and 1.16

```
export POD_CIDR=10.88.0.0/16
curl https://docs.projectcalico.org/v3.10/manifests/calico.yaml -O
sed -i -e "s?192.168.0.0/16?$POD_CIDR?g" calico.yaml
kubectl apply -f calico.yaml
```

Check the status of the cluster and wait for all pods to be in `Running` and `Ready 1/1` state.

```
$ kubectl get pods -A
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-6b64bcd855-6tdtk   1/1     Running   0          6m15s
kube-system   calico-node-pn2pp                          1/1     Running   0          6m15s
kube-system   coredns-5644d7b6d9-6s25d                   1/1     Running   0          23m
kube-system   coredns-5644d7b6d9-9m5gt                   1/1     Running   0          23m
kube-system   etcd-okd.zinox.com                         1/1     Running   0          22m
kube-system   kube-apiserver-okd.zinox.com               1/1     Running   0          22m
kube-system   kube-controller-manager-okd.zinox.com      1/1     Running   0          22m
kube-system   kube-proxy-zlngl                           1/1     Running   0          23m
kube-system   kube-scheduler-okd.zinox.com               1/1     Running   0          22m
```

Our single node basic Kubernetes cluster is now up and running.

```
$ kubectl get nodes -o wide
NAME            STATUS   ROLES    AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION
CONTAINER-RUNTIME
okd.zinox.com   Ready    master   24m   v1.16.2   10.191.66.28   <none>        CentOS Linux 7 (Core)   3.10.0-1062.4.1.el7.x86_64
cri-o://1.16.0
```

## Create an admin account

```
kubectl --namespace kube-system create serviceaccount admin
```

Grant Cluster Role Binding to the `admin` account

```
kubectl create clusterrolebinding admin --serviceaccount=kube-system:admin --clusterrole=cluster-admin
```

## Install kubectl on client machines

We will use the existing VM - which already has `kubectl` and the GUI to run a browser. 

However, you can use `kubectl` from a client machine to manage the Kubernetes environment. Follow the [link](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for installing `kubectl` on your chice of client machine (Windows, MacBook or Linux). 

## Install busybox to check

```
kubectl create -f https://k8s.io/examples/admin/dns/busybox.yaml
```

## Install test service and deployment to check kube-proxy
```
kubectl apply -f https://raw.githubusercontent.com/servicemeshbook/consul/master/scripts/12-api-v1-deployment.yaml0

sudo crictl ps | grep api
```

## Sanity check for the cluster

[Check this link for testing the cluster](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/)

Check pods
```
$ kubectl get pods
NAME                     READY   STATUS    RESTARTS   AGE
api-v1-f9b675d9d-x6ktq   1/1     Running   0          103s
busybox                  1/1     Running   0          4m43s
```

Scale api-v1 deployment
```
kubectl scale deploy api-v1 --replicas=3
```

Find out the IP address of the `api-v1` service and repeat curl and check if L4 routing is taking place or not. Check the pod name and it should be different on each curl.
```
API_IP=$(kubectl get svc api-v1 -o jsonpath='{.spec.clusterIP}') ; echo $API_IP

curl $API_IP:8080
curl $API_IP:8080
curl $API_IP:8080
curl $API_IP:8080
```

## Install helm and tiller 

Starting with Helm 3, the tiller will not be required. However, we will be installing Helm v2.15.2

In principle tiller can be installed using `helm init`.

```
VERSION="v2.15.2"
curl -s https://storage.googleapis.com/kubernetes-helm/helm-${VERSION}-linux-amd64.tar.gz | tar xz

sudo mv linux-amd64/helm /bin
rm -fr linux-amd64
```

Create `tiller` service accoun and grant cluster admin to the `tiller` service account.

```
kubectl -n kube-system create serviceaccount tiller

kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
```
Helm can be installed with and without security. If no security is required (like demo/test environment), follow Option - 1 or follow option - 2 to install helm with security.

### Option - 1 : No security, ideal for running in a sandbox environment.

Initialize the `helm` and it will install `tiller` server in Kubernetes.

```
helm init --service-account tiller
```

Check helm version

```
helm version --short

Client: v2.15.2+g8dce272
Server: v2.15.2+g8dce272
```

If you installed helm without secruity, skip to the [next](#Install-Kubernetes-dashboard) section.

### Option - 2 : With TLS security, ideal for running in production.

Install step

```
$ curl -LOs https://github.com/smallstep/cli/releases/download/v0.10.1/step_0.10.1_linux_amd64.tar.gz

$ tar xvfz step_0.10.1_linux_amd64.tar.gz

$ sudo mv step_0.10.1/bin/step /bin

$ mkdir -p ~/helm
$ cd ~/helm
$ step certificate create --profile root-ca "My iHelm Root CA" root-ca.crt root-ca.key
$ step certificate create intermediate.io inter.crt inter.key --profile intermediate-ca --ca ./root-ca.crt --ca-key ./root-ca.key
$ step certificate create helm.io helm.crt helm.key --profile leaf --ca inter.crt --ca-key inter.key --no-password --insecure --not-after 17520h
$ step certificate bundle root-ca.crt inter.crt ca-chain.crt

$ helm init \
--override 'spec.template.spec.containers[0].command'='{/tiller,--storage=secret}' \
--tiller-tls --tiller-tls-verify \
--tiller-tls-cert=./helm.crt \
--tiller-tls-key=./helm.key \
--tls-ca-cert=./ca-chain.crt \
--service-account=tiller

$ cd ~/.helm
$ cp ~/helm/helm.crt cert.pem
$ cp ~/helm/helm.key key.pem
$ rm -fr ~/helm ## Copy dir somewhere and protect it.
```

## Update helm repository

Update Helm repo

```
$ helm repo update
```

If secure helm is used, use --tls at the end of helm commands to use TLS between helm and server.

List Helm repo

```
$ helm repo list
NAME  	URL                                             
stable	https://kubernetes-charts.storage.googleapis.com
local 	http://127.0.0.1:8879/charts   
```

## Install Kubernetes dashboard

Install kubernetes dashboard helm chart

```
helm install stable/kubernetes-dashboard --name k8web --namespace kube-system --set fullnameOverride="dashboard"

Note: add --tls above if using secure helm
```

```
$ kubectl get pods -n kube-system
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-6b64bcd855-6tdtk   1/1     Running   0          28m
calico-node-pn2pp                          1/1     Running   0          28m
coredns-5644d7b6d9-6s25d                   1/1     Running   0          45m
coredns-5644d7b6d9-9m5gt                   1/1     Running   0          45m
dashboard-7ddc4c9d66-4nhcd                 1/1     Running   0          16s
etcd-okd.zinox.com                         1/1     Running   0          44m
kube-apiserver-okd.zinox.com               1/1     Running   0          44m
kube-controller-manager-okd.zinox.com      1/1     Running   0          44m
kube-proxy-zlngl                           1/1     Running   0          45m
kube-scheduler-okd.zinox.com               1/1     Running   0          44m
tiller-deploy-684c9f98f5-srxrw             1/1     Running   0          72s
```

Check helm charts that we deployed

```
$ helm list
NAME    REVISION        UPDATED                         ---
k8web   1               Mon Sep 30 22:21:01 2019        ---

--- STATUS          CHART                           APP VERSION     NAMESPACE
--- DEPLOYED        kubernetes-dashboard-1.10.0     1.10.1          kube-system
```

Check service names for the dashboard

```
$ $ kubectl get svc -n kube-system
NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                  AGE
dashboard       ClusterIP   10.98.217.60   <none>        443/TCP                  53s
kube-dns        ClusterIP   10.96.0.10     <none>        53/UDP,53/TCP,9153/TCP   46m
tiller-deploy   ClusterIP   10.97.34.17    <none>        44134/TCP                109s
```

We will patch the dashboard service from CluserIP to NodePort so that we could run the dashboard using the node IP address.

```
kubectl -n kube-system patch svc dashboard --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"}]'
```

### Run Kubernetes dashboard

Check the internal DNS server

```
kubectl exec -it busybox -- cat /etc/resolv.conf

nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local servicemesh.local
options ndots:5
```

Internal service name resolution.

```
$ kubectl exec -it busybox -- nslookup kube-dns.kube-system.svc.cluster.local
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kube-dns.kube-system.svc.cluster.local
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

$ kubectl exec -it busybox -- nslookup hostnames.default.svc.cluster.local
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      hostnames.default.svc.cluster.local
Address 1: 10.98.229.90 hostnames.default.svc.cluster.local
```

Edit VM's `/etc/resolv.conf` to add Kubernetes DNS server

```
sudo vi /etc/resolv.conf
```

Add the following two lines for name resolution of Kubernetes services and save file.

```
search cluster.local
nameserver 10.96.0.10
```

### Get authentication token

If you need to access Kubernetes environment remotely, create a `~/.kube` directory on your client machine and then scp the `~/.kube/config` file from the Kubernetes master to your `~/.kube` directory.

Run this on the Kubernetes master node

```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin | awk '{print $1}')
```

Output:

```
$ kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin | awk '{print $1}')
Name:         admin-token-2f4z8
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: admin
              kubernetes.io/service-account.uid: 81b744c4-ab0b-11e9-9823-00505632f6a0

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1025 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi10b2tlbi0yZjR6OCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJhZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjgxYjc0NGM0LWFiMGItMTFlOS05ODIzLTAwNTA1NjMyZjZhMCIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTphZG1pbiJ9.iaWllI4XHQ9UQQHwXQRaafW7pSD6EpNJ_rEaFqkd5qwedxgJodD9MJ90ujlZx4UtvUt2rTURHsJR-qdbFoUEVbE3CcrfwGkngYFrnU6xjwO3KydndyhLb6v6DKdUH3uQdMnu4V1RVYBCq2Q1bOsejsgNUIxJw1R8N7eUpIte64qUfGYtrFT_NBTnA9nEZPfPAiSlBBXbC0ZSBKXzqOD4veCXsqlc0yy5oXHOoMjROm-Uhv4Oh0gTwdpb-at8Y0p9mPjIy9IQuzSo3Pg5hDKMex4Pwm8WLus4wAaS4mZKu2PI3O2-hhep3GlyvuVH8pOiXQ4p1TI5c0qdDs2rQRs4ow
```

Highlight the authentication token from your screen, right click to copy to the clipboard.

Find out the node port for the `dashboard` service.

```
$ kubectl get svc -n kube-system
NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                  AGE
dashboard       NodePort    10.98.217.60   <none>        443:32332/TCP            3m22s
kube-dns        ClusterIP   10.96.0.10     <none>        53/UDP,53/TCP,9153/TCP   48m
tiller-deploy   ClusterIP   10.97.34.17    <none>        44134/TCP                4m18s
```

Doubleclick Google Chrome from the desktop of the VM and run https://localhost:31869 and change the port number as per your output.

Click `Token` and paste the token from the clipboard (Right click and paste).

You have Kubernetes 1.15.5 single node environment ready for you now. 

The following are optional and are not recommended. Skip to [this](#power-down-vm).

## Check if kube-prxy is OK. There must be two entries for the hostnames

```
sudo iptables-save | grep hostnames

-A KUBE-SERVICES ! -s 10.142.0.0/16 -d 10.98.229.90/32 -p tcp -m comment --comment "default/hostnames: cluster IP" -m tcp --dport 80 -j KUBE-MARK-MASQ
-A KUBE-SERVICES -d 10.98.229.90/32 -p tcp -m comment --comment "default/hostnames: cluster IP" -m tcp --dport 80 -j KUBE-SVC-NWV5X2332I4OT4T3
[vikram@istio04 ~]$ sudo iptables-save | grep hostnames
-A KUBE-SERVICES ! -s 10.142.0.0/16 -d 10.98.229.90/32 -p tcp -m comment --comment "default/hostnames: cluster IP" -m tcp --dport 80 -j KUBE-MARK-MASQ
-A KUBE-SERVICES -d 10.98.229.90/32 -p tcp -m comment --comment "default/hostnames: cluster IP" -m tcp --dport 80 -j KUBE-SVC-NWV5X2332I4OT4T3
```


## Install Metrics server (Optional)

Metrics server is required if we need to run `kubectl top` commands to show the metrics.

```
helm install stable/metrics-server --name metrics --namespace kube-system --set fullnameOverride="metrics" --set args="{--logtostderr,--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP\,ExternalIP\,Hostname}"
```

Make sure that the `v1beta1.metrics.k8s.io` service is available

```
$ kubectl get apiservice v1beta1.metrics.k8s.io
NAME                     SERVICE               AVAILABLE   AGE
v1beta1.metrics.k8s.io   kube-system/metrics   True        13m
```

If the service shows `FailedDiscoveryCheck` or `MissingEndpoints`, it might be the firewall issue. Make sure that https is enabled through the firewall.

Run the following.
```
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```
Wait for few minutes, `kubectl top nodes` and `kubectl top pods -A` should show output.


## Install VMware Octant (Optional)

VMware provides [Octant](https://github.com/vmware/octant) an alternative to Kubernetes dashboard.

You can install `Octant` on your Windows, MacBook, Linux and it is a simple to use an alternative to using Kubernetes dashboard. Refer to [https://github.com/vmware/octant](https://github.com/vmware/octant) for details to install Octant.

## Install Prometheus and Grafana (Optional)

This is optional if we do not have enough resources in the VM to deploy additional charts. 

```
helm install stable/prometheus-operator --namespace monitoring --name mon

Note: add --tls above if using secure helm
```

Check monitoring pods

```
$ kubectl -n monitoring get pods
NAME                                     READY   STATUS    RESTARTS   AGE
alertmanager-mon-alertmanager-0          2/2     Running   0          28s
mon-grafana-75954bf666-jgnkd             2/2     Running   0          33s
mon-kube-state-metrics-ff5d6c45b-s68np   1/1     Running   0          33s
mon-operator-6b95cf776f-tqdp8            1/1     Running   0          33s
mon-prometheus-node-exporter-9mdhr       1/1     Running   0          33s
prometheus-mon-prometheus-0              3/3     Running   1          18s
```

Check Services

```
$ kubectl -n monitoring get svc
NAME                                   TYPE        CLUSTER-IP       EXTERNAL-IP   --- 
alertmanager-operated                  ClusterIP   None             <none>        --- 
mon-grafana                            ClusterIP   10.98.241.51     <none>        --- 
mon-kube-state-metrics                 ClusterIP   10.111.186.181   <none>        --- 
mon-prometheus-node-exporter           ClusterIP   10.108.189.227   <none>        --- 
mon-prometheus-operator-alertmanager   ClusterIP   10.106.154.135   <none>        --- 
mon-prometheus-operator-operator       ClusterIP   10.110.132.10    <none>        --- 
mon-prometheus-operator-prometheus     ClusterIP   10.106.118.107   <none>        --- 
prometheus-operated                    ClusterIP   None             <none>        --- 

--- PORT(S)             AGE
--- 9093/TCP,6783/TCP   19s
--- 80/TCP              23s
--- 8080/TCP            23s
--- 9100/TCP            23s
--- 9093/TCP            23s
--- 8080/TCP            23s
--- 9090/TCP            23s
--- 9090/TCP            9s
```

The grafana UI can be opened using: `http://10.98.241.51` for service `mon-grafana`. The IP address will be different in your case.

A node port can also be configured for the `mon-grafana` to use the local IP address of the VM instead of using cluster IP address.

```
# kubectl get svc -n monitoring mon-grafana
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
mon-grafana   ClusterIP   10.105.49.113   <none>        80/TCP    95s
```

Edit the service by running `kubectl edit svc -n monitoring mon-grafana` and change `type` from `ClusterIP` to `NodePort`.

Find out the `NodePort` for the `mon-grafana` service.

```
# kubectl get svc -n monitoring mon-grafana
NAME          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
mon-grafana   NodePort   10.105.49.113   <none>        80:32620/TCP   3m15s
```

The grafana UI can be opened through http://localhost:32620 and this node port will be different in your case.

The default user id is `admin` and the password is `prom-operator`. This can be seen through `kubectl -n monitoring get secret mon-grafana -o yaml` and then run `base64 -d` againgst the encoded value for `admin-user` and `admin-password` secret.

You can also open Prometheus UI either by NodePort method as descibed above or by using `kubectl port-forward`

Open a command line window to proxy the Prometheus pod's port to the localhost

First terminal
```
kubectl port-forward -n monitoring prometheus-mon-prometheus-operator-prometheus-0 9090
```

Open `http://localhost:9090` to open the Prometheus UI and `http://localhost:9090/alerts` for alerts.

### Delete prometheus 

If you need to free-up resources from the VM, delete prometheus using the following clean-up procedure.

```
helm delete mon --purge
helm delete ns monitoring
kubectl -n kube-system delete crd \
           alertmanagers.monitoring.coreos.com \
           podmonitors.monitoring.coreos.com \
           prometheuses.monitoring.coreos.com \
           prometheusrules.monitoring.coreos.com \
           servicemonitors.monitoring.coreos.com

Note: add --tls above if using secure helm
```

## Uninstall Kubernetes and Docker

In case Kuberenetes needs to be uninstalled.

Find out node name using `kubectl get nodes`

```
kubectl drain <node name> --delete-local-data --force --ignore-daemonsets
kubectl delete node <node name>
```

Remove kubeadm

```
systemctl stop kubelet
kubeadm reset
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
yum -y remove kubeadm kubectl kubelet kubernetes-cni kube*
rm -fr ~/.kube
```

Stop crio and empty `/var/lib/container/storage/`
```
systemctl stop crio
rm -fr /var/lib/container/storage/*

cleanupdirs="/var/lib/etcd /etc/kubernetes /etc/cni /opt/cni /var/lib/cni /var/run/calico"
for dir in $cleanupdirs; do
  echo "Removing $dir"
  rm -rf $dir
done
```

## Power down VM

Click `Player` > `Power` > `Shutdown Guest`.

 It is highly recommended that you take a backup of the directory after installing Kubernetes environment. You can restore the VM from the backup to start again, should you need it.

The files in the directory may show as:

The output shown using `git bash` running in Windows.

```
$ ls -lh
total 7.3G
-rw-r--r-- 1 vikram 197609 2.1G Jul 21 09:44 dockerbackend.vmdk
-rw-r--r-- 1 vikram 197609 8.5K Jul 21 09:44 kube01.nvram
-rw-r--r-- 1 vikram 197609    0 Jul 20 16:34 kube01.vmsd
-rw-r--r-- 1 vikram 197609 3.5K Jul 21 09:44 kube01.vmx
-rw-r--r-- 1 vikram 197609  261 Jul 21 08:58 kube01.vmxf
-rw-r--r-- 1 vikram 197609 5.2G Jul 21 09:44 osdisk.vmdk
-rw-r--r-- 1 vikram 197609 277K Jul 21 09:44 vmware.log
```

Copy above directory to your backup drive for use it later.

## Power up VM

Locate `kube01.vmx` and right click to open it either using `VMware Player` or `VMware WorkStation`.

Open `Terminal` and run `kubectl get pods -A` and wait for all pods to be ready and in `Running` status.

## Conclusion

This is a pretty basic Kubernetes cluster just by using a single VM - which is good for learning purposes. In reality, we should use a Kubernetes distribution built by a provider such as RedHat OpenShift or IBM Cloud Private or use public cloud provider such as AWS, GKE, Azure or many others.

## Ascinema Cast

