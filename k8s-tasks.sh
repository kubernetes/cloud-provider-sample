########################################################################  
#############    UPGRADE CLUSTER   ###################
######################################################################## 

# Upgrade All Kubernetes Components on the Control Plane Node
# Switch to the appropriate context with kubectl:
kubectl config use-context acgk8s
Upgrade kubeadm:

sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubeadm=1.22.2-00
Drain the control plane node:

kubectl drain acgk8s-control --ignore-daemonsets
Plan the upgrade:

sudo kubeadm upgrade plan v1.22.2
Apply the upgrade:

sudo kubeadm upgrade apply v1.22.2
Upgrade kubelet and kubectl:

sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubelet=1.22.2-00 kubectl=1.22.2-00
Reload:

sudo systemctl daemon-reload
Restart kubelet:

sudo systemctl restart kubelet
Uncordon the control plane node:

kubectl uncordon acgk8s-control
Upgrade All Kubernetes Components on the Worker Node
Drain the worker1 node:

kubectl drain acgk8s-worker1 --ignore-daemonsets --force
SSH into the node:

ssh acgk8s-worker1
Install a new version of kubeadm:

sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubeadm=1.22.2-00
Upgrade the node:

sudo kubeadm upgrade node
Upgrade kubelet and kubectl:

sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubelet=1.22.2-00 kubectl=1.22.2-00
Reload:

sudo systemctl daemon-reload
Restart kubelet:

sudo systemctl restart kubelet
Type exit to exit the node.

Uncordon the node:

kubectl uncordon acgk8s-worker1
Repeat the process above for acgk8s-worker2 to upgrade the other worker node.

########################################################################  
#############    Back UP ETCD data & Restore    ###################
######################################################################## 

Back Up the etcd Data
From the terminal, log in to the etcd server:

ssh etcd1
Back up the etcd data:

ETCDCTL_API=3 etcdctl snapshot save /home/cloud_user/etcd_backup.db \
--endpoints=https://etcd1:2379 \
--cacert=/home/cloud_user/etcd-certs/etcd-ca.pem \
--cert=/home/cloud_user/etcd-certs/etcd-server.crt \
--key=/home/cloud_user/etcd-certs/etcd-server.key
Restore the etcd Data from the Backup
Stop etcd:

sudo systemctl stop etcd
Delete the existing etcd data:

sudo rm -rf /var/lib/etcd
Restore etcd data from a backup:

sudo ETCDCTL_API=3 etcdctl snapshot restore /home/cloud_user/etcd_backup.db \
--initial-cluster etcd-restore=https://etcd1:2380 \
--initial-advertise-peer-urls https://etcd1:2380 \
--name etcd-restore \
--data-dir /var/lib/etcd
Set database ownership:

sudo chown -R etcd:etcd /var/lib/etcd
Start etcd:

sudo systemctl start etcd
Verify the system is working:

ETCDCTL_API=3 etcdctl get cluster.name \
--endpoints=https://etcd1:2379 \
--cacert=/home/cloud_user/etcd-certs/etcd-ca.pem \
--cert=/home/cloud_user/etcd-certs/etcd-server.crt \
--key=/home/cloud_user/etcd-certs/etcd-server.key

########################################################################  
########    Drain Worker Node 1 ##############
Create a Pod That Will Only Be Scheduled on Nodes with a Specific Label
######################################################################## 

Attempt to drain the worker1 node:
kubectl drain acgk8s-worker1

Does the node drain successfully?
Override the errors and drain the node:

kubectl drain acgk8s-worker1 --delete-local-data --ignore-daemonsets --force
                        or
kubectl drain acgk8s-worker1 --ignore-daemonsets --delete-emptydir-data --force

kubectl label nodes acgk8s-worker2 disk=fast


kubectl get pod fast-nginx -n dev -o wide

########################################################################  
########################################################################  
Create a PersistentVolume
Create a Pod That Uses the PersistentVolume for Storage
Expand the PersistentVolumeClaim
######################################################################## 

