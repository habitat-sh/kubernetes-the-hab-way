# Kubernetes The Hab Way

Kubernetes the Hab way shows setting up a Kubernetes cluster in which
Kubernetes components are [Habitat](habitat.sh) packages and services.

## Requirements

* Linux or MacOS on the host (Windows is not supported)
* [Vagrant](https://www.vagrantup.com/downloads.html)
* [Virtual Box](https://www.virtualbox.org/wiki/Downloads)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [cfssl](https://github.com/cloudflare/cfssl#installation) (with cfssljson)
* [jq](https://stedolan.github.io/jq/download/) Command-line JSON processor

## Quickstart

```
vagrant destroy -f ; ./scripts/setup
```

The above command can be used to setup everything from scratch with a single
command. Setup will take several minutes. Use the [smoke test](#smoke-test) to
verify things work correctly.

## Step-by-step Setup

### Virtual machines

```
vagrant up
```

Verify all 3 Habitat supervisors are running and have joined the ring:

```
./scripts/list-peers
```

### Certificates & kubeconfig

Create a CA and certificates for all components:

```
./scripts/generate-ssl-certificates
```

Create necessary kubeconfig files:

```
./scripts/generate-kubeconfig
```

### etcd

First we start etcd:

```
# On node-0, node-1 and node-2
sudo hab svc load --topology leader core/etcd
```

NB: a service with topology `leader` requires at least 3 members. Only when 3
members are alive, the service will start. We take advantage of that to make
sure all three etcd member nodes start with the same "initial cluster" setting
(and therefore have the same cluster ID to be able to form a cluster).

For each node and service instance, we have to add an etcd environment config
file with service instance specific configuration, as that's not supported
by Habitat (as far as I know).

```
# On each node, replace X with node number (i.e. '0' for node-0 and so on)
cat >/var/lib/etcd-env-vars <<ETCD_ENV_VARS
export ETCD_LISTEN_CLIENT_URLS="https://192.168.222.1X:2379"
export ETCD_LISTEN_PEER_URLS="https://192.168.222.1X:2380"
export ETCD_ADVERTISE_CLIENT_URLS="https://192.168.222.1X:2379"
export ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.222.1X:2380"
ETCD_ENV_VARS
```

Now we have to update the etcd.default service group configuration to make etcd
use our SSL certifcates (this has only to be done once for a service group; we
use node-0 here):

```
# On node-0
for f in /vagrant/certificates/{etcd.pem,etcd-key.pem,ca.pem}; do sudo hab file upload etcd.default $(date +%s) "${f}"; done
sudo hab config apply etcd.default $(date +%s) /vagrant/config/svc-etcd.toml
```

Finally we verify etcd is running:

```
# On node-0
export ETCDCTL_API=3
etcdctl --debug --insecure-transport=false --endpoints https://192.168.222.10:2379 --cacert /vagrant/certificates/ca.pem --cert /vagrant/certificates/etcd.pem --key /vagrant/certificates/etcd-key.pem member list
```

All 3 members should be started:

```
b82a52a6ff5c63c3, started, node-1, https://192.168.222.11:2380, https://192.168.222.11:2379
ddfa35d3c9a4c741, started, node-2, https://192.168.222.12:2380, https://192.168.222.12:2379
f1986a6cf0ad46aa, started, node-0, https://192.168.222.10:2380, https://192.168.222.10:2379
```

### Kubernetes controller components

#### kubernetes-apiserver service

Create kubernetes directory and assign ownership to hab user

```
# On node-0
sudo mkdir -p /var/run/kubernetes
sudo chown hab:hab /var/run/kubernetes
```

Start the kubernetes-apiserver service:

```
# On node-0
sudo hab svc load core/kubernetes-apiserver
```

Now we have to update the kubernetes-apiserver.default service group
configuration to provide the necessary SSL certificates and keys:

```
# On node-0
for f in /vagrant/certificates/{kubernetes.pem,kubernetes-key.pem,ca.pem,ca-key.pem}; do sudo hab file upload kubernetes-apiserver.default $(date +%s) "${f}"; done
sudo hab config apply kubernetes-apiserver.default $(date +%s) /vagrant/config/svc-kubernetes-apiserver.toml
```

Verify the API server is running:

```
# On the host
curl --cacert certificates/ca.pem --cert certificates/admin.pem --key certificates/admin-key.pem https://192.168.222.10:6443/version
```

#### kubernetes-controller-manager

Similar to the kube-apiserver setup, start the service, provide necessary
files and configure it accordingly:

```
# On node-0
sudo hab svc load core/kubernetes-controller-manager
for f in /vagrant/certificates/{ca.pem,ca-key.pem}; do sudo hab file upload kubernetes-controller-manager.default $(date +%s) "${f}"; done
sudo hab config apply kubernetes-controller-manager.default $(date +%s) /vagrant/config/svc-kubernetes-controller-manager.toml
```

#### kubernetes-scheduler

The kube-scheduler doesn't require specific configuration:

```
# On node-0
sudo hab svc load core/kubernetes-scheduler
```

### `kubernetes-the-hab-way` kubectl context

Create a new context and set it default:

```
./scripts/setup-kubectl
```

### Configure RBAC auth for kubelets

```
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: Kubernetes
EOF
```

### Verify the controller is ready

To verify that all controller components are ready, run:

```
kubectl get cs
```

Output should look like this:

```
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
```

### Kubernetes worker components

#### kube-proxy

Configure and start kube-proxy:

```
# On node-0
sudo mkdir -p /var/lib/kube-proxy
sudo cp /vagrant/config/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
sudo hab svc load core/kubernetes-proxy
sudo hab config apply kubernetes-proxy.default $(date +%s) /vagrant/config/svc-kubernetes-proxy.toml

# On node-1 and node-2
sudo mkdir -p /var/lib/kube-proxy
sudo cp /vagrant/config/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
sudo hab svc load core/kubernetes-proxy
```

After successful setup, `iptables -nvL -t nat` will show multiple new chains,
e.g. `KUBE-SERVICES`.

To reach services from your host, you can do:

```
# On Linux
sudo route add -net 10.32.0.0/24 gw 192.168.222.10
# On macOS
sudo route -n add -net 10.32.0.0/24 192.168.222.10
```

#### kubelet

Configure and start the kubelet:

```
# On each node, replace X with node number (i.e. '0' for node-0 and so on)
sudo mkdir -p /var/lib/kubelet-config/cni
cat >/var/lib/kubelet-config/kubelet <<KUBELET_CONFIG
{
  "kind": "KubeletConfiguration",
  "apiVersion": "kubelet.config.k8s.io/v1beta1",
  "podCIDR": "10.2X.0.0/16"
}
KUBELET_CONFIG
cat >/var/lib/kubelet-config/cni/10-bridge.conf <<CNI_CONFIG
{
  "cniVersion": "0.3.1",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cnio0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [{"subnet": "10.2X.0.0/16"}]
    ],
    "routes": [{"dst": "0.0.0.0/0"}]
  }
}
CNI_CONFIG
for f in /vagrant/certificates/{$(hostname)/node.pem,$(hostname)/node-key.pem,ca.pem} /vagrant/config/$(hostname)/kubeconfig; do sudo cp "${f}" "/var/lib/kubelet-config/"; done
sudo hab svc load core/kubernetes-kubelet
sudo hab config apply kubernetes-kubelet.default $(date +%s) /vagrant/config/svc-kubelet.toml # noop on repeated calls
```

Verify the 3 nodes are up and ready:

```
kubectl get nodes
```

Output should look like this:

```
NAME      STATUS    ROLES     AGE       VERSION
node-0    Ready     <none>    23m       v1.8.2
node-1    Ready     <none>    23m       v1.8.2
node-2    Ready     <none>    23m       v1.8.2
```

### Make node names resolvable for k8s components
```
# On each node
cat >>/etc/hosts <<DNS_IPS
192.168.222.10 node-0
192.168.222.11 node-1
192.168.222.12 node-2
DNS_IPS
```

### Add DNS support
```
# on the host
kubectl create -f manifests/kube-dns.yaml
```

## Smoke test

Test the setup by creating a Nginx deployment, expose it and send a request
to the service IP:

```
# On Linux
sudo route add -net 10.32.0.0/24 gw 192.168.222.10
# On macOS
sudo route -n add -net 10.32.0.0/24 192.168.222.10

# Run the smoke test
./scripts/smoke-test
```

## DNS test
Verify that kube-dns works

```
# On the host
kubectl run --rm -ti --restart=Never --image=busybox:1.28.0-glibc busybox -- nslookup kubernetes
```

Output should look like this:
```
Server:    10.32.0.10
Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local
pod "busybox" deleted
```

## Updating Kubernetes components to patch versions
You can update the kubernetes components from one patch version to the next, e.g `1.11.1` to `1.11.2` with the following commands.

```
# On the host
origin=core ./scripts/updates/update-kube-apiserver # updates kubernetes apiserver

origin=core ./scripts/updates/update-kube-controller-manager # updates kubernetes controller manager

origin=core ./scripts/updates/update-kube-proxy # updates kubernetes proxy

origin=core ./scripts/updates/update-kube-scheduler # updates kubernetes scheduler

origin=core ./scripts/updates/update-kubelet # updates kubelet
```
