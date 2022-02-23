ssh aen@c1-cp1
cd ~/content/course/02/demo

#Note: this restore process is for a locally hosted etcd running in a static pod.
#If you need more information on more advanced restore scenarios such as an external cluster check out:
#https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/recovery.md#restoring-a-cluster 


#Check out some of the key etcd configuration information
#Container image and tag, command, --data dir, and mounts and volumes for both etcd-certs and etcd-data
kubectl describe pod etcd-c1-cp1 -n kube-system


#The configuration for etcd comes from the static pod manifest, check out the listen-client-urls, data-dir, volumeMounts, volumes/
sudo more /etc/kubernetes/manifests/etcd.yaml


#You can get the runtime values from ps -aux
ps -aux | grep etcd




#Let's get etcdcdl on our local system here...by downloading it from github.
#TODO: Update RELEASE to match your release version!!!
#We can find out the version of etcd we're running by using etcd --version inside the etcd pod.
kubectl exec -it etcd-c1-cp1 -n kube-system -- /bin/sh -c 'ETCDCTL_API=3 /usr/local/bin/etcd --version' | head
export RELEASE="3.4.13"
wget https://github.com/etcd-io/etcd/releases/download/v${RELEASE}/etcd-v${RELEASE}-linux-amd64.tar.gz
tar -zxvf etcd-v${RELEASE}-linux-amd64.tar.gz
cd etcd-v${RELEASE}-linux-amd64
sudo cp etcdctl /usr/local/bin


#Quick check to see if we have etcdctl...
ETCDCTL_API=3 etcdctl --help | head 



#First, let's create create a secret that we're going to delete and then get back when we run the restore.
kubectl create secret generic test-secret \
    --from-literal=username='svcaccount' \
    --from-literal=password='S0mthingS0Str0ng!'


#Define a variable for the endpoint to etcd
ENDPOINT=https://127.0.0.1:2379


#Verify we're connecting to the right cluster...define your endpoints and keys
sudo ETCDCTL_API=3 etcdctl --endpoints=$ENDPOINT \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    member list


#Take the backup saving it to /var/lib/dat-backup.db...
#Be sure to copy that to remote storage when doing this for real
sudo ETCDCTL_API=3 etcdctl --endpoints=$ENDPOINT \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    snapshot save /var/lib/dat-backup.db


#Read the metadata from the backup/snapshot to print out the snapshot's status 
sudo ETCDCTL_API=3 etcdctl --write-out=table snapshot status /var/lib/dat-backup.db


#now let's delete an object and then run a restore to get it back
kubectl delete secret test-secret 


#Run the restore to a second folder...this will restore to the current directory
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/lib/dat-backup.db


#Confirm our data is in the restore directory 
sudo ls -l


#Move the old etcd data to a safe location
sudo mv /var/lib/etcd /var/lib/etcd.OLD


#Restart the static pod for etcd...
#if you kubectl delete it will NOT restart the static pod as it's managed by the kubelet not a controller or the control plane.
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps | grep etcd
CONTAINER_ID=$(sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps  | grep etcd | awk '{ print $1 }')
echo $CONTAINER_ID


#Stop the etcd container from our etcd pod and move our restored data into place
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock stop $CONTAINER_ID
sudo mv ./default.etcd /var/lib/etcd


#Wait for etcd, the scheduler and controller manager to recreate
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps



#Is our secret back? This may take a minute or two to come back due to caching.
kubectl get secret test-secret




#Another common restore method is to update the data-path to the restored data path in the static pod manifest.
#The kubelet will restart the pod due to the configuation change


#Let's delete an object again then run a restore to get it back
kubectl delete secret test-secret 


#Using the same backup from earlier
#Run the restore to a define data-dir, rather than the current working directory
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/lib/dat-backup.db --data-dir=/var/lib/etcd-restore


#Update the static pod manifest to point to that /var/lib/etcd-restore...in three places
#Update 
#    - --data-dir=/var/lib/etcd-restore
#...
#   volumeMounts:
#    - mountPath: /var/lib/etcd-restore
#...
#   volumes:
#    - hostPath:
#        name: etcd-data
#        path: /var/lib/etcd-restore
sudo cp /etc/kubernetes/manifests/etcd.yaml .
sudo vi /etc/kubernetes/manifests/etcd.yaml


#This will cause the control plane pods to restart...let's check it at the container runtime level
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps


#Is our secret back?
kubectl get secret test-secret 


#remove etcdctl from the Control Plane Node node if you want. 
#Put back the original etcd.yaml
kubectl delete secret test-secret 
sudo cp etcd.yaml /etc/kubernetes/manifests/
sudo rm /var/lib/dat-backup.db 
sudo rm /usr/local/bin/etcdctl
sudo rm -rf /var/lib/etcd.OLD
sudo rm -rf /var/lib/etcd-restore
rm ~/content/course/02/demo/etcd-v3.4.13-linux-amd64.tar.gz



#Additional ways to get etcdctl
#You can start up a container just for etcdctl
#Get the container image and tag for our etcd
ETCDIMAGE=$(kubectl get pod etcd-c1-cp1 -n kube-system -o jsonpath='{ .spec.containers[].image }')
echo $ETCDIMAGE


#Start a conatainer with etcdctl in there...key things are adding the container to the host network,
# mounting the certificates and backup volumes
mkdir backup
sudo docker run -it \
    --network host \
    --volume /etc/kubernetes/pki/etcd:/etc/kubernetes/pki/etcd \
    --volume $(pwd)/backup:/backup \
    $ETCDIMAGE \
    /usr/local/bin/etcdctl --help | head