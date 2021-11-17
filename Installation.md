Introduction
This lab will allow you to practice the process of building a new Kubernetes cluster. You will be given a set of Linux servers, and you will have the opportunity to turn these servers into a functioning Kubernetes cluster. This will help you build the skills necessary to create your own Kubernetes clusters in the real world.

If you wish, you can set an appropriate hostname for each node.
# INSTALLATION
On the control plane node:
```
sudo hostnamectl set-hostname k8s-control
sudo hostnamectl set-hostname k8s-worker1
sudo hostnamectl set-hostname k8s-worker2
```

On the first worker node:
On the second worker node:

On all nodes, set up the hosts file to enable all the nodes to reach each other using these hostnames.
sudo vi /etc/hosts
On all nodes, add the following at the end of the file. You will need to supply the actual private IP address for each node.
```
<control plane node private IP> k8s-control
<worker node 1 private IP> k8s-worker1
<worker node 2 private IP> k8s-worker2
```
Log out of all three servers and log back in to see these changes take effect.
On all nodes, set up containerd. You will need to load some kernel modules and modify some system settings as part of this
process.

Solution
Log in to the lab server using the credentials provided:


Install Packages
(Note: The following steps must be performed on all three nodes.).
Create configuration file for containerd:
```
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
```
Load modules:
```
sudo modprobe overlay
sudo modprobe br_netfilter
```
Set system configurations for Kubernetes networking:
```
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
```
Apply new settings:
```
sudo sysctl --system
```
Install containerd:
```
sudo apt-get update && sudo apt-get install -y containerd
```
Create default configuration file for containerd:
```
sudo mkdir -p /etc/containerd
```
Generate default containerd configuration and save to the newly created default file:
```
sudo containerd config default | sudo tee /etc/containerd/config.toml
```
Restart containerd to ensure new configuration file usage: & Verify that containerd is running.
```
sudo systemctl restart containerd

sudo systemctl status containerd
```


Disable swap:
```
sudo swapoff -a
```
Disable swap on startup in /etc/fstab:
```
sudo sed -i '/ swap / s/^\(.\*\)$/#\1/g' /etc/fstab
```
Install dependency packages:
```
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
```
Download and add GPG key:
```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```
Add Kubernetes to repository list:
```
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
```
Update package listings:
```
sudo apt-get update
```
Install Kubernetes packages (Note: If you get a dpkg lock message, just wait a minute or two before trying the command again)
```
sudo apt-get install -y kubelet=1.22.0-00 kubeadm=1.22.0-00 kubectl=1.22.0-00
```
Turn off automatic updates:
```
sudo apt-mark hold kubelet kubeadm kubectl
```

Initialize the Cluster
Initialize the Kubernetes cluster on the control plane node using kubeadm (Note: This is only performed on the Control Plane Node):
```
sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.22.0
```
Set kubectl access:
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
Test access to cluster:
```
kubectl get nodes
```
Install the Calico Network Add-On
On the Control Plane Node, install Calico Networking:
```
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```
Check status of the control plane node:
```
kubectl get nodes
```
Join the Worker Nodes to the Cluster
In the Control Plane Node, create the token and copy the kubeadm join command (NOTE:The join command can also be found in the output from kubeadm init command):
```
kubeadm token create --print-join-command
```
In both Worker Nodes, paste the kubeadm join command to join the cluster. Use sudo to run it as root:
```
sudo kubeadm join ...
```
In the Control Plane Node, view cluster status (Note: You may have to wait a few moments to allow all nodes to become ready):

```
kubectl get nodes
```

# UPGRADE USING KUBEADM

Upgrade the Control Plane

Upgrade kubeadm:
```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubeadm=1.22.2-00
```

Make sure it upgraded correctly:
```
kubeadm version
```
Drain the control plane node:

```
kubectl drain k8s-control --ignore-daemonsets
```
Plan the upgrade:

```
sudo kubeadm upgrade plan v1.22.2
```
Upgrade the control plane components:

```
sudo kubeadm upgrade apply v1.22.2
```
Upgrade kubelet and kubectl on the control plane node:

```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubelet=1.22.2-00 kubectl=1.22.2-00
```
Restart kubelet:

```
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```
Uncordon the control plane node:

```
kubectl uncordon k8s-control
```
Verify the control plane is working:

```
kubectl get nodes
```
If it shows a NotReady status, run the command again after a minute or so. It should become Ready.

Upgrade the Worker Nodes
Note: In a real-world scenario, you should not perform upgrades on all worker nodes at the same time. Make sure enough nodes are available at any given time to provide uninterrupted service.

### Worker Node 1
Run the following on the control plane node to drain worker node 1:

```
kubectl drain k8s-worker1 --ignore-daemonsets --force
```
You may get an error message that certain pods couldn't be deleted, which is fine.

### In a new terminal window, log in to worker node 1:

ssh cloud_user@<WORKER_1_PUBLIC_IP_ADDRESS>

Upgrade kubeadm on worker node 1:

```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubeadm=1.22.2-00

kubeadm version
```

Back on worker node 1, upgrade the kubelet configuration on the worker node:

```
sudo kubeadm upgrade node
```
Upgrade kubelet and kubectl on worker node 1:

```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubelet=1.22.2-00 kubectl=1.22.2-00
```
Restart kubelet:
```
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```
From the control plane node, uncordon worker node 1:

```
kubectl uncordon k8s-worker1
```
### Worker Node 2
From the control plane node, drain worker node 2:

```
kubectl drain k8s-worker2 --ignore-daemonsets --force
```
In a new terminal window, log in to worker node 2:

ssh cloud_user@<WORKER_2_PUBLIC_IP_ADDRESS>
Upgrade kubeadm:

```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubeadm=1.22.2-00

kubeadm version
```

Back on worker node 2, perform the upgrade:
```
sudo kubeadm upgrade node

sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubelet=1.22.2-00 kubectl=1.22.2-00


sudo systemctl daemon-reload
sudo systemctl restart kubelet

```

From the control plane node, uncordon worker node 2:

```
kubectl uncordon k8s-worker2
```
Still in the control plane node, verify the cluster is upgraded and working:

```
kubectl get nodes
```
If they show a NotReady status, run the command again after a minute or so. They should become Ready.
