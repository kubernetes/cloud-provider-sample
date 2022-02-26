########################################################################  
###          Short Cuts  
######################################################################## 

```
echo "set ts=2 sw=2" >> ~/.vimrc

echo "autocmd FileType yaml setlocal et ts=2 ai sw=2 nu sts=0" >> ~/.vimrc

alias k='kubectl' 
alias kcsc='k config set-context'
alias kcuc="k config use-context"

alias gen="--dry-run=client -o yaml"
alias kaf="kubectl apply -f"

# Get K8S resources
alias kgp="k get pods -o wide"
alias kgd="k get deployment -o wide"
alias kgs="k get svc -o wide"
alias kgno="k get nodes -o wide"
alias kgn="k get namespace"
alias kgrb="kubectl get rolebinding"
alias kgr="kubectl get role"


alias kdpf='kubectl delete pod --force --grace-period=0'

# Describe K8S resources 
alias kdp="k describe pod"
alias kdd="k describe deployment"
alias kds="k describe service"
alias kdno="k describe node"
alias sb="--sort-by"
alias ke="kubectl edit"
alias kdrb="kubectl describe rolebinding"
alias kdr="kubectl describe role"

```

########################################################################  
###          Troubleshooting Clusters    
######################################################################## 

```
networking
---------------
If you want to spin up a throw away container for debugging.
$ kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash

And if you want to spin up a container on the host's network namespace.
$ kubectl run tmp-shell --rm -i --tty --overrides='{"spec": {"hostNetwork": true}}' --image nicolaka/netshoot -- /bin/bash


backing up ETCD
----------------
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
snapshot save /var/lib/dat-backup.db

ETCDCTL_API=3 etcdctl --write-out=table \
snapshot status /var/lib/dat-backup.db

sudo systemctl stop etcd
sudo rm -rf /var/lib/etcd


restore the ETCD DATA
--------------------
sudo ETCDCTL_API=3 etcdctl snapshot restore /home/cloud_user/etcd_backup.db \
--initial-cluster etcd-restore=https://etcd1:2380 \
--initial-advertise-peer-urls https://etcd1:2380 \
--name etcd-restore \
--data-dir /var/lib/etcd

sudo chown -R etcd:etcd /var/lib/etcd
sudo systemctl start etcd

ETCDCTL_API=3 etcdctl get cluster.name \
--endpoints=https://etcd1:2379 \
--cacert=/home/cloud_user/etcd-certs/etcd-ca.pem \
--cert=/home/cloud_user/etcd-certs/etcd-server.crt \
--key=/home/cloud_user/etcd-certs/etcd-server.key

sudo more /etc/kubernetes/manifests/etcd.yaml
ps -aux | grep etcd

kubectl exec -it etcd-c1-cp1 -n kube-system -- /bin/sh -c 'ETCDCTL_API=3 /usr/local/bin/etcd --version' | head

#First, let's create create a secret that we're going to delete and then get back when we run the restore.
------------------------------------------------------------------------------------------------------------
kubectl create secret generic test-secret \
    --from-literal=username='svcaccount' \
    --from-literal=password='S0mthingS0Str0ng!'

#Read the metadata from the backup/snapshot to print out the snapshot's status
------------------------------------------------------------------------------------------------------------
sudo ETCDCTL_API=3 etcdctl --write-out=table snapshot status /var/lib/dat-backup.db

#now let's delete an object and then run a restore to get it back
------------------------------------------------------------------------------------------------------------
kubectl delete secret test-secret 

#Run the restore to a second folder...this will restore to the current directory
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/lib/dat-backup.db

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

#Get the container image and tag for our etcd
ETCDIMAGE=$(kubectl get pod etcd-c1-cp1 -n kube-system -o jsonpath='{ .spec.containers[].image }')
echo $ETCDIMAGE

sudo docker run -it \
    --network host \
    --volume /etc/kubernetes/pki/etcd:/etc/kubernetes/pki/etcd \
    --volume $(pwd)/backup:/backup \
    $ETCDIMAGE \
    /usr/local/bin/etcdctl --help | head

#Restart the static pod for etcd...
#if you kubectl delete it will NOT restart the static pod as it's managed by the kubelet not a controller or the control plane.
sudo docker ps  | grep k8s_etcd_etcd
CONTAINER_ID=$(sudo docker ps | grep k8s_etcd_etcd | awk '{ print $1 }')
echo $CONTAINER_ID

kubectl version --short
kubectl drain c1-cp1 --ignore-daemonsets
sudo kubeadm upgrade plan

kubectl create deployment nginx --image=nginx
PODNAME=$(kubectl get pods -l app=nginx -o jsonpath='{ .items[0].metadata.name }')
echo $PODNAME
kubectl logs $PODNAME


PODNAME=$(kubectl get pods -l app=loggingdemo -o jsonpath='{ .items[0].metadata.name }')
echo $PODNAME


#But we need to specify which container inside the pods
kubectl logs $PODNAME -c container1
#We can access all container logs which will dump each containers in sequence
kubectl logs $PODNAME --all-containers


#If we need to follow a log, we can do that...helpful in debugging real time issues
#This works for both single and multi-container pods
kubectl logs $PODNAME --all-containers --follow
kubectl get pods --selector app=loggingdemo
kubectl logs --selector app=loggingdemo --all-containers  > allpods.txt
kubectl logs --selector app=loggingdemo --all-containers --tail 5

systemctl status kubelet.service
journalctl -u kubelet.service
journalctl -u kubelet.service | grep -i ERROR


#Time bounding your searches can be helpful in finding issues add --no-pager for line wrapping
journalctl -u kubelet.service --since today --no-pager

sudo ls /var/log/containers
sudo tail /var/log/containers/kube-apiserver-c1-cp1*

kubectl get events 
kubectl get events --sort-by='.metadata.creationTimestamp'
 

#Create a flawed deployment
kubectl create deployment nginx --image ngins


#We can filter the list of events using field selector
kubectl get events --field-selector type=Warning
kubectl get events --field-selector type=Warning,reason=Failed

kubectl get pods --all-namespaces --field-selector spec.nodeName=acgk8s-worker2
#to use API for same query find below
curl --cacert ca.crt --cert apiserver.crt --key apiserver.key  https://<server>:<port>/api/v1/namespaces/<namespace>/pods?fieldSelector=spec.nodeName%3Dsomenodename
#We can also monitor the events as they happen with watch
kubectl get events --watch &
kubectl scale deployment loggingdemo --replicas=5
kubectl get events --namespace kube-system


#These events are also available in the object as part of kubectl describe, in the events section
kubectl describe replicaset nginx-7df5f8b5cb #Update to your replicaset name

#But the event data is still availble from the cluster's events, even though the objects are gone.
kubectl get events --sort-by='.metadata.creationTimestamp'
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0
kubectl scale  deployment hello-world --replicas=3
kubectl get pods -l app=hello-world

#It's a list of objects, so let's display the pod names
kubectl get pods -l app=hello-world -o jsonpath='{ .items[*].metadata.name }'
kubectl get pods -l app=hello-world -o jsonpath='{ .items[*].metadata.name }{"\n"}'
#Get all container images in use by all pods in all namespaces
kubectl get pods --all-namespaces -o jsonpath='{ .items[*].spec.containers[*].image }{"\n"}'
kubectl get nodes c1-cp1 -o json | more
kubectl get nodes -o jsonpath="{.items[*].status.addresses[?(@.type=='InternalIP')].address}"
kubectl get pods -A -o jsonpath='{ .items[*].metadata.name }{"\n"}' --sort-by=.metadata.name
kubectl get pods -A -o jsonpath='{ .items[*].metadata.name }{"\n"}' \
    --sort-by=.metadata.creationTimestamp \
    --output=custom-columns='NAME:metadata.name,CREATIONTIMESTAMP:metadata.creationTimestamp'


kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{.spec.containers[*].image}{"\n"}{end}'

kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' \
    --sort-by=.spec.containers[*].image

#We can use range again to clean up the output if we want
kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="Hostname")].address}{"\n"}{end}'
kubectl get pods -A -o jsonpath='{ .items[*].spec.containers[*].image }' --sort-by=.spec.containers[*].image
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name }{"\t"}{.spec.containers[*].image }{"\n"}{end}' --sort-by=.spec.containers[*].image


#Adding in a spaces or tabs in the output to make it a bit more readable
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[*].image}{"\n"}{end}'
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

#Verify Metrics Server is responsive:
kubectl get --raw /apis/metrics.k8s.io/

#Is the Metrics Server running?
kubectl get pods --namespace kube-system

#We can look at our system pods, CPU and memory 
kubectl top pods --all-namespaces
#And create a deployment and scale it.
kubectl create deployment nginx --image=nginx
kubectl scale  deployment nginx --replicas=3
kubectl top nodes
kubectl top pods -l app=cpuburner
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory
kubectl top pods --containers



##example
kubectl top pod -n beebox-mobile --sort-by cpu --selector app=auth

NAME       CPU(cores)   MEMORY(bytes)
auth-web   100m         7Mi
auth1      0m           0Mi
auth2      0m           0Mi

HIGH_CPU_POD=$(kubectl top pod -n web --sort-by cpu -l app=auth | awk 'FNR == 2 {print $1}' | head -n 1 )

sudo systemctl status kubelet.service
sudo systemctl enable kubelet.service 
sudo systemctl start kubelet.service
sudo systemctl status kubelet.service --no-pager
sudo journalctl -u kubelet.service --no-pager
sudo ls -la /var/lib/kubelet 


#And now fixup that config by renaming the file and and restarting the kubelet
#Another option here would have been to edit the systemd unit configuration for the kubelet in /etc/systemd/system/kubelet.service.d/10-kubeadm.conf.
#We're going to look at that in the next demo below.
sudo mv /var/lib/kubelet/config.yml  /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet.service 


#But since we edited the unit file, we neede to reload the unit files (configs)...then restart the service
sudo systemctl daemon-reload
sudo systemctl restart kubelet 


#check our Nodes' statuses
kubectl get nodes



#Let's ask our container runtime, what's up...well there's pods running on this node, but no control plane pods.
#That's your clue...no control plane pods running...what starts up the control plane pods...static pod manifests
sudo docker ps
#If you are using containerd
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps
sudo ls -laR /etc/kubernetes/manifests

#What's the next step after the pods are created by the replication controler? Scheduling...
kubectl get events --sort-by='.metadata.creationTimestamp'

#That's defined in the static pod manifest
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml

#We can also look at the events to get this information
kubectl get events --sort-by='.metadata.creationTimestamp'
kubectl get events --sort-by='.metadata.creationTimestamp'

SERVICEIP=$(kubectl get service hello-world-5 -o jsonpath='{ .spec.clusterIP }')
echo $SERVICEIP
#Access the service inside the cluster...connection refused...why?
curl http://$SERVICEIP

#Let's check out the endpoints behind the service...there's no endpoints. Why? 
kubectl describe service hello-world-5
kubectl get endpoints hello-world-5

```


############################################################################ 
###   Cluster Architecture, Installtion & configuration #############
############################################################################ 

```
kubectl get nodes -o wide
kubectl get pods --namespace kube-system -o wide
kubectl api-resources | grep pod
kubectl explain pod.spec.containers | more 
kubectl explain pod --recursive | more 

kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0


#But let's deploy a single "bare" pod that's not managed by a controller...
kubectl run hello-world-pod --image=gcr.io/google-samples/hello-app:1.0

kubectl create deployment hello-world \
     --image=gcr.io/google-samples/hello-app:1.0 \
     --dry-run=client -o yaml > deployment.yaml

kubectl expose deployment hello-world \
     --port=80 --target-port=8080 \
     --dry-run=client -o yaml > service.yaml

```

############################################################################ 
###  Services and Networking #############
############################################################################ 
```
kubectl create deployment hello-world-service-single --image=gcr.io/google-samples/hello-app:1.0
kubectl scale deployment hello-world-service-single --replicas=2
kubectl expose deployment hello-world-service-single --port=80 --target-port=8080 --type=ClusterIP

INGRESSIP=$(kubectl get ingress -o jsonpath='{ .items[].status.loadBalancer.ingress[].ip }')
curl http://$INGRESSIP

#Demo 3 - Multiple Services with path based routing
#Let's create two additional services
kubectl create deployment hello-world-service-blue --image=gcr.io/google-samples/hello-app:1.0
kubectl create deployment hello-world-service-red  --image=gcr.io/google-samples/hello-app:1.0

kubectl expose deployment hello-world-service-blue --port=4343 --target-port=8080 --type=ClusterIP
kubectl expose deployment hello-world-service-red  --port=4242 --target-port=8080 --type=ClusterIP
kubectl get ingress --watch
#Our paths are routing to their correct services, if we specify a host header or use a DNS name to access the ingress. That's how the rule will route the request.
curl http://$INGRESSIP/red  --header 'Host: path.example.com'
curl http://$INGRESSIP/blue --header 'Host: path.example.com'


#Example prefix matches...these will all match and get routed to red
curl http://$INGRESSNODEPORTIP:$NODEPORT/red/1  --header 'Host: path.example.com'
curl http://$INGRESSNODEPORTIP:$NODEPORT/red/2  --header 'Host: path.example.com'


#Example Exact mismatches...these will all 404
curl http://$INGRESSNODEPORTIP:$NODEPORT/Blue  --header 'Host: path.example.com'
curl http://$INGRESSNODEPORTIP:$NODEPORT/blue/1  --header 'Host: path.example.com'
curl http://$INGRESSNODEPORTIP:$NODEPORT/blue/2  --header 'Host: path.example.com'


#If we don't specify a path we'll get a 404 while specifying a host header. 
#We'll need to configure a path and backend for / or define a default backend for the service
curl http://$INGRESSIP/     --header 'Host: path.example.com'

kubectl describe ingress ingress-path


#Now we'll hit the default backend service, single
curl http://$INGRESSIP/ --header 'Host: path.example.com'

kubectl get ingress --watch

curl http://$INGRESSIP/ --header 'Host: red.example.com'
curl http://$INGRESSIP/ --header 'Host: blue.example.com'

#TLS Example
#1 - Generate a certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout tls.key -out tls.crt -subj "/C=US/ST=ILLINOIS/L=CHICAGO/O=IT/OU=IT/CN=tls.example.com"


#2 - Create a secret with the key and the certificate
kubectl create secret tls tls-secret --key tls.key --cert tls.crt

#Test access to the hostname...we need --resolve because we haven't registered the DNS name
#TLS is a layer lower than host headers, so we have to specify the correct DNS name. 
curl https://tls.example.com:443 --resolve tls.example.com:443:$INGRESSIP --insecure --verbose

INGRESSNODEPORTIP=$(kubectl get ingresses ingress-single -o jsonpath='{ .status.loadBalancer.ingress[].ip }')
NODEPORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{ .spec.ports[?(@.name=="http")].nodePort }')
echo $INGRESSNODEPORTIP:$NODEPORT
curl http://$INGRESSNODEPORTIP:$NODEPORT

kubectl get service -n ingress-nginx ingress-nginx-controller
NODEPORTHTTPS=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{ .spec.ports[?(@.name=="https")].nodePort }')
echo $NODEPORTHTTPS
curl https://tls.example.com:$NODEPORTHTTPS/ \
    --resolve tls.example.com:$NODEPORTHTTPS:$INGRESSNODEPORTIP \
    --insecure --verbose
curl http://$INGRESSNODEPORTIP:$NODEPORT/ --header 'Host: red.example.com'
curl http://$INGRESSNODEPORTIP:$NODEPORT/ --header 'Host: blue.example.com'


#Here is the Pod's interface and it's IP. 
#This interface is attached to the cbr0 bridge on the Node to get access to the Pod network. 
PODNAME=$(kubectl get pods -o jsonpath='{ .items[0].metadata.name }')
kubectl exec -it $PODNAME -- ip addr


#And inside the pod, there's a default route in the pod to the interface 10.244.0.1 which is the brige interface cbr0.
#Then the Node will route it on the Node network for reachability to other nodes.
kubectl exec -it $PODNAME -- route


#Access an AKS Node via SSH so we can examine it's network config which uses kubenet
#https://docs.microsoft.com/en-us/azure/aks/ssh#configure-virtual-machine-scale-set-based-aks-clusters-for-ssh-access
NODENAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl debug node/$NODENAME -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11


#Check out the routes, notice the route to the local Pod Network matching PodCIDR for this Node sending traffic to cbr0
#The routes for the other PodCIDR ranges on the other Nodes are implemented in the cloud's virtual network. 
route

#Let's hop inside a pod and check out it's networking, a single interface an IP on the Pod Network
#The line below will get a list of pods from the label query and return the name of the first pod in the list
PODNAME=$(kubectl get pods --selector=app=hello-world -o jsonpath='{ .items[0].metadata.name }')
echo $PODNAME
kubectl exec -it $PODNAME -- /bin/sh
ip addr
exit

kubectl describe deployment coredns --namespace kube-system | more

#The configmap defining the CoreDNS configuration and we can see the default forwarder is /etc/resolv.conf
kubectl get configmaps --namespace kube-system coredns -o yaml | more
kubectl logs --namespace kube-system --selector 'k8s-app=kube-dns' --follow 


#Run some DNS queries against the kube-dns service cluster ip to ensure everything works...
SERVICEIP=$(kubectl get service --namespace kube-system kube-dns -o jsonpath='{ .spec.clusterIP }')
nslookup www.pluralsight.com $SERVICEIP
nslookup www.centinosystems.com $SERVICEIP

kubectl exec -it $PODNAME -- cat /etc/resolv.conf

#Get the address of our DNS Service again...just in case
SERVICEIP=$(kubectl get service --namespace kube-system kube-dns -o jsonpath='{ .spec.clusterIP }')


#For one of the pods replace the dots in the IP address with dashes for example 192.168.206.68 becomes 192-168-206-68
#We'll look at some additional examples of Service Discovery in the next module too.
nslookup 192-168-206-[xx].default.pod.cluster.local $SERVICEIP

#Our Services also get DNS A records
#There's more on service A records in the next demo
kubectl get service 
nslookup hello-world.default.svc.cluster.local $SERVICEIP

#Find the name of a Node running one of the DNS Pods running...so we're going to observe DNS queries there.
DNSPODNODENAME=$(kubectl get pods --namespace kube-system --selector=k8s-app=kube-dns -o jsonpath='{ .items[0].spec.nodeName }')
echo $DNSPODNODENAME


CLUSTERIP=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.clusterIP }')
PORT=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.ports[].port }')
NODEPORT=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.ports[].nodePort }')

curl http://c1-node3:$NODEPORT

#And a Node port service is also listening on a Cluster IP, in fact the Node Port traffic is routed to the ClusterIP
echo $CLUSTERIP:$PORT
curl http://$CLUSTERIP:$PORT

LOADBALANCERIP=$(kubectl get service hello-world-loadbalancer -o jsonpath='{ .status.loadBalancer.ingress[].ip }')
curl http://$LOADBALANCERIP:$PORT

#The record is in the form <servicename>.<namespace>.<clusterdomain>. You may get an error that says ** server can't find hello-world.api.example.com: NXDOMAIN this is ok.
nslookup hello-world-api.default.svc.cluster.local 10.96.0.10

```
########################################################################  
###        WorkLoad Scheduling   ###################
######################################################################## 

```
kubectl label pod hello-world-[tab][tab] app=DEBUG --overwrite
kubectl get pods --show-labels


#Demo 4 - Taking over an existing Pod in a ReplicaSet, relabel that pod to bring 
#it back into the scope of the replicaset...what's kubernetes going to do?
kubectl label pod hello-world-[tab][tab] app=hello-world-pod-me --overwrite

kubectl rollout status deployment hello-world

#Both replicasets remain, and that will become very useful shortly when we use a rollback :)
kubectl get replicaset

#The NewReplicaSet, check out labels, replicas, status and pod-template-hash
kubectl describe replicaset hello-world-b77646c68

kubectl rollout history deployment hello-world --revision=2
kubectl rollout history deployment hello-world --revision=3


#Let's undo our rollout to revision 2, which is our v2 container.
kubectl rollout undo deployment hello-world --to-revision=2
kubectl rollout status deployment hello-world
echo $?

kubectl rollout restart deployment hello-world 

kubectl get daemonsets --namespace kube-system kube-proxy
#So we'll get three since we have 3 workers and 1 Control Plane Node in our cluster and the Control Plane Node is set to run only system pods
kubectl get daemonsets -o wide

MYPOD=$(kubectl get pods -l app=hello-world-app | grep hello-world | head -n 1 | awk {'print $1'})
echo $MYPOD
kubectl label pods $MYPOD app=not-hello-world --overwrite

#Follow job status with a watch
kubectl get job --watch

#Let's get some more details about the job...labels and selectors, Start Time, Duration and Pod Statuses
kubectl describe job hello-world-job

watch 'kubectl describe job | head -n 11'

kubectl get cronjobs -o yaml
```
########################################################################  
###   configMap,   Storage , PV, PVC   ###################
######################################################################## 
```
PODNAME=$(kubectl get pods | grep hello-world-alpha | awk '{print $1}' | head -n 1)
kubectl exec -it $PODNAME -- /bin/sh -c "printenv | sort"

#Demo 1 - Creating and accessing Secrets
#Generic - Create a secret from a local file, directory or literal value
#They keys and values are case sensitive
kubectl create secret generic app1 \
    --from-literal=USERNAME=app1login \
    --from-literal=PASSWORD='S0methingS@Str0ng!'


#Opaque means it's an arbitrary user defined key/value pair. Data 2 means two key/value pairs in the secret.
#Other types include service accounts and container registry authentication info
kubectl get secrets
kubectl describe secret app1


#If we need to access those at the command line...
#These are wrapped in bash expansion to add a newline to output for readability
echo $(kubectl get secret app1 --template={{.data.USERNAME}} )
echo $(kubectl get secret app1 --template={{.data.USERNAME}} | base64 --decode )

echo $(kubectl get secret app1 --template={{.data.PASSWORD}} )
echo $(kubectl get secret app1 --template={{.data.PASSWORD}} | base64 --decode )

#Let's access a shell on the Pod
kubectl exec -it $PODNAME -- /bin/sh

#Now we see the path we defined in the Volumes part of the Pod Spec
#A directory for each KEY and it's contents are the value
ls /etc/appconfig
cat /etc/appconfig/USERNAME
cat /etc/appconfig/PASSWORD
exit

#There's also an envFrom example in here for you too...
kubectl create secret generic app1 --from-literal=USERNAME=app1login --from-literal=PASSWORD='S0methingS@Str0ng!'


#Create the deployment, envFrom will create  enviroment variables for each key in the named secret app1 with and set it's value set to the secrets value
kubectl apply -f deployment-secrets-env-from.yaml

PODNAME=$(kubectl get pods | grep hello-world-secrets-env-from | awk '{print $1}' | head -n 1)
echo $PODNAME 
kubectl exec -it $PODNAME -- /bin/sh
printenv | sort
exit

#Let's pull down a hello-world image from gcr
sudo ctr images pull gcr.io/google-samples/hello-app:1.0
#Let's get a listing of images from ctr to confim our image is downloaded
sudo ctr images list


#Tagging our image in the format your registry, image and tag
#You'll be using your own repository, so update that information here. 
#  source_ref: gcr.io/google-samples/hello-app:1.0    #this is the image pulled from gcr
#  target_ref: docker.io/nocentino/hello-app:ps       #this is the image you want to push into your private repository
sudo ctr images tag gcr.io/google-samples/hello-app:1.0 docker.io/nocentino/hello-app:ps
sudo ctr images push docker.io/nocentino/hello-app:ps --user $USERNAME


#Create our secret that we'll use for our image pull...
#Update the paramters to match the information for your repository including the servername, username, password and email.
kubectl create secret docker-registry private-reg-cred \
    --docker-server=https://index.docker.io/v2/ \
    --docker-username=$USERNAME \
    --docker-password=$PASSWORD \
    --docker-email=$EMAIL


#Ensure the image doesn't exist on any of our nodes...or else we can get a false positive since our image would be cached on the node
#Caution, this will delete *ANY* image that begins with hello-app
ssh aen@c1-node1 'sudo ctr --namespace k8s.io image ls "name~=hello-app" -q | sudo xargs ctr --namespace k8s.io image rm'

kubectl delete secret private-reg-cred
sudo ctr images remove docker.io/nocentino/hello-app:ps
sudo ctr images remove gcr.io/google-samples/hello-app:1.0

kubectl create configmap appconfigprod \
    --from-literal=DATABASE_SERVERNAME=sql.example.local \
    --from-literal=BACKEND_SERVERNAME=be.example.local

kubectl create configmap appconfigqa \
    --from-file=appconfigqa


#Each creation method yeilded a different structure in the ConfigMap
kubectl get configmap appconfigprod -o yaml

#Let's see or configured enviroment variables
PODNAME=$(kubectl get pods | grep hello-world-configmaps-env-prod | awk '{print $1}' | head -n 1)
echo $PODNAME

kubectl exec -it $PODNAME -- /bin/sh 
ls /etc/appconfig
cat /etc/appconfig/appconfigqa
exit

kubectl exec -it $PODNAME -- /bin/sh 
watch cat /etc/appconfig/appconfigqa
exit

kubectl get pv -o yaml
kubectl get pv --sort-by=.spec.capacity.storage

#Review the created resources, Status, Access Mode and Reclaim policy is set to Reclaim rather than Delete. 
kubectl get PersistentVolume pv-nfs-data
kubectl describe PersistentVolumeClaim pvc-nfs-data

kubectl get service nginx-nfs-service
SERVICEIP=$(kubectl get service | grep nginx-nfs-service | awk '{ print $3 }')
#Let's access that application to see our application data...
curl http://$SERVICEIP/web-app/demo.html

kubectl config use-context 'CSCluster'
kubectl describe StorageClass default
kubectl describe StorageClass managed-premium


kubectl get PersistentVolumeClaim



#Get a list of the current StorageClasses kubectl get StorageClass.
kubectl get StorageClass

#A closer look at the SC, you can see the Reclaim Policy is Delete since we didn't set it in our StorageClass yaml
kubectl describe StorageClass managed-standard-ssd


#Let's use our new StorageClass
kubectl apply -f AzureDiskCustomStorageClass.yaml


#And take a closer look at our new Storage Class, Reclaim Policy Delete
kubectl get PersistentVolumeClaim
kubectl get PersistentVolume
kubectl config use-context kubernetes-admin@kubernetes

kubectl scale deployment hello-world-web --replicas=4
#Clean up when we're finished, delete our labels and Pods
kubectl label node c1-node2 disk-
kubectl label node c1-node3 hardware-

#View the scheduling of the pods in the cluster.
kubectl get node -L disk,hardware
kubectl get pods -o wide

#Label our nodes with something descriptive
kubectl label node c1-node2 disk=local_ssd
kubectl label node c1-node3 hardware=local_gpu

kubectl taint nodes c1-node1 key=MyTaint:NoSchedule

kubectl scale deployment hello-world-web --replicas=2

kubectl drain c1-node3 --ignore-daemonsets
#Something that will cause pods to get created
kubectl uncordon c1-node3

```

########################################################################  
###  RBAC, Security 
######################################################################## 
```
kubectl config view
kubectl config view --raw


#Let's read the certificate information out of our kubeconfig file
#Look for Subject: CN= is the username which is kubernetes-admin, it's also in the group (O=) system:masters
kubectl config view --raw -o jsonpath='{ .users[*].user.client-certificate-data }' | base64 --decode > admin.crt
openssl x509 -in admin.crt -text -noout | head


#We can use -v 6 to see the api request, and return code which is 200.
kubectl get pods -v 6


#Clean up files no longer needed
rm admin.crt


#2 - Working with Service Accounts
#Getting Service Accounts information
kubectl get serviceaccounts


#A service account can contain image pull secrets and also mountable secrets, notice the mountable secrets name
kubectl describe serviceaccounts default

#Pods can only access service accounts in the same namespace
kubectl describe secret default-token-8fb46 #<--- change this to your default service account name


#Create a Service Accounts
kubectl create serviceaccount mysvcaccount1


#This new service account will get it's own secret.
kubectl describe serviceaccounts mysvcaccount1


#Use serviceAccountName as serviceAccount is deprecated.
PODNAME=$(kubectl get pods -l app=nginx -o jsonpath='{ .items[*].metadata.name }')
kubectl get pod $PODNAME -o yaml

#Let's see how the secret is available inside the pod
PODNAME=$(kubectl get pods -l app=nginx -o jsonpath='{ .items[*].metadata.name }')
kubectl exec $PODNAME -it -- /bin/bash
ls /var/run/secrets/kubernetes.io/serviceaccount/
cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt 
cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 
cat /var/run/secrets/kubernetes.io/serviceaccount/token 


#Load the token and cacert into variables for reuse
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt


#You're able to authenticate to the API Server with the user...and retrieve some basic and safe information from the API Server
#See this link for more details on API Discovery Roles: https://kubernetes.io/docs/reference/access-authn-authz/rbac/#discovery-roles
curl --cacert $CACERT -X GET https://kubernetes.default.svc/api/
curl --cacert $CACERT --header "Authorization: Bearer $TOKEN" -X GET https://kubernetes.default.svc/api/


#But it doesn't have any permissions to access objects...this user is not authorized to access pods
curl --cacert $CACERT --header "Authorization: Bearer $TOKEN" -X GET https://kubernetes.default.svc/api/v1/namespaces/default/pods
exit 


#We can also use impersonation to help with our authorization testing
kubectl auth can-i list pods --as=system:serviceaccount:default:mysvcaccount1
kubectl get pods -v 6 --as=system:serviceaccount:default:mysvcaccount1

#1 - Changing authorization for a service account
#We left off with where serviceaccount didn't have access to the API Server to access Pods
kubectl auth can-i list pods --as=system:serviceaccount:default:mysvcaccount1


#But we can create an RBAC Role and bind that to our service account
#We define who, can perform what verbs on what resources
kubectl create role demorole --verb=get,list --resource=pods
kubectl create rolebinding demorolebinding --role=demorole --serviceaccount=default:mysvcaccount1 


#Then the service account can access the API with the 
#https://kubernetes.io/docs/reference/access-authn-authz/rbac/#service-account-permissions
kubectl auth can-i list pods --as=system:serviceaccount:default:mysvcaccount1
kubectl get pods -v 6 --as=system:serviceaccount:default:mysvcaccount1


#Go back inside the pod again...
kubectl get pods 
PODNAME=$(kubectl get pods -l app=nginx -o jsonpath='{ .items[*].metadata.name }')
kubectl exec $PODNAME -it -- /bin/bash
#Load the token and cacert into variables for reuse
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt


#Now I can view objects...this isn't just for curl but for any application. 
#Apps commonly use libraries to programmaticly interact with the api server for cluster state information 
curl --cacert $CACERT --header "Authorization: Bearer $TOKEN" -X GET https://kubernetes.default.svc/api/v1/namespaces/default/pods
exit 

#etcd's cert setup, sa (serviceaccount) and more.
ls -l /etc/kubernetes/pki


#Read the ca.crt to view the certificates information, useful to determine the validity date of the certifcate
#You can use this command to read the information about any of the *.crt in this folder
#Be sure to check out the validity and the Subject CN
openssl x509 -in /etc/kubernetes/pki/ca.crt -text -noout | more




#2 - kubeconfig file location, for system components, controller manager, kubelet and scheduler.
ls /etc/kubernetes


#certificate-authority-data is a base64 encoded ca.cert
#You can also see the server for the API Server is https
#And there is also a client-certificate-data which is the client certificate used.
#And client-key-data is the private key for the client cert. these are used to authenticate the client to the api server
sudo more /etc/kubernetes/scheduler.conf
sudo kubectl config view --kubeconfig=/etc/kubernetes/scheduler.conf 


#The kube-proxy has it's kube-config as a configmap rather than a file on the file system.
kubectl get configmap -n kube-system kube-proxy -o yaml

#1 - Create a certificate for a new user
#https://kubernetes.io/docs/concepts/cluster-administration/certificates/#cfssl
#Create a private key
openssl genrsa -out demouser.key 2048


#Generate a CSR
#CN (Common Name) is your username, O (Organization) is the Group
#If you get an error Can't load /home/USERNAME/.rnd into RNG - comment out RANDFILE from /etc/ssl/openssl.conf 
# see this link for more details https://github.com/openssl/openssl/issues/7754#issuecomment-541307674
openssl req -new -key demouser.key -out demouser.csr -subj "/CN=demouser"


#The certificate request we'll use in the CertificateSigningRequest
cat demouser.csr


#The CertificateSigningRequest needs to be base64 encoded
#And also have the header and trailer pulled out.
cat demouser.csr | base64 | tr -d "\n" > demouser.base64.csr


#UPDATE: If you're on 1.19+ use this CertificateSigningRequest
#Submit the CertificateSigningRequest to the API Server
#Key elements, name, request and usages (must be client auth)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: demouser
spec:
  groups:
  - system:authenticated  
  request: $(cat demouser.base64.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

#UPDATE: If you're on 1.18.x or below use this CertificateSigningRequest
#Submit the CertificateSigningRequest to the API Server
#Key elements, name, request and usages (must be client auth)
#cat <<EOF | kubectl apply -f -
#apiVersion: certificates.k8s.io/v1beta1
#kind: CertificateSigningRequest
#metadata:
#  name: demouser
#spec:
#  groups:
#  - system:authenticated  
#  request: $(cat demouser.base64.csr)
#  usages:
#  - client auth
#EOF


#Let's get the CSR to see it's current state. The CSR will delete after an hour
#This should currently be Pending, awaiting administrative approval
kubectl get certificatesigningrequests


#Approve the CSR
kubectl certificate approve demouser


#If we get the state now, you'll see Approved, Issued. 
#The CSR is updated with the certificate in .status.certificate
kubectl get certificatesigningrequests demouser 


#Retrieve the certificate from the CSR object, it's base64 encoded
kubectl get certificatesigningrequests demouser \
  -o jsonpath='{ .status.certificate }'  | base64 --decode


#Let's go ahead and save the certificate into a local file. 
#We're going to use this file to build a kubeconfig file to authenticate to the API Server with
kubectl get certificatesigningrequests demouser \
  -o jsonpath='{ .status.certificate }'  | base64 --decode > demouser.crt 


#Check the contents of the file
cat demouser.crt


#Read the certficate itself
#Key elements: Issuer is our CA, Validity one year, Subject CN=demousers
openssl x509 -in demouser.crt -text -noout | head -n 15


#Now that we have the certificate we can use that to build a kubeconfig file with to log into this cluster.
#We'll use demouser.key and demouser.crt
#More on that in an upcoming demo
ls demouser.*

kubectl config view
kubectl config view --raw
more ~/.kube/config


kubectl config get-contexts

#set our current context to the Azure context
kubectl config use-context CSCluster


#run a command to communicate with our cluster.
kubectl cluster-info

#set our current context to the local cluster context
kubectl config use-context kubernetes-admin@kubernetes
kubectl cluster-info


#To delete kubeconfig entries
kubectl config delete-context CSCluster
kubectl config delete-cluster CSCluster
kubectl config unset users.clusterUser_Kubernetes-Cloud_CSCluster

#This could be a role, but I'm choosing the view ClusterRole here for read only access
kubectl create clusterrolebinding demouserclusterrolebinding \
  --clusterrole=view --user=demouser


#Create the cluster entry, notice the kubeconfig parameter, this will generate a new file using that name.
# embed-certs puts the cert data in the kubeconfig entry for this user
kubectl config set-cluster kubernetes \
  --server=https://10.0.1.101:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --kubeconfig=demouser.conf

#Let's confirm the cluster is create in there.
kubectl config view --kubeconfig=demouser.conf


#Add user to new kubeconfig file demouser.conf
#Keep in mind there's several authentication methods, we're focusing on certificates here
kubectl config set-credentials demouser \
  --client-key=demouser.key \
  --client-certificate=demouser.crt \
  --embed-certs=true \
  --kubeconfig=demouser.conf


#Now we have a Cluster and a User
kubectl config view --kubeconfig=demouser.conf


#Add the context, context name, cluster name, user name
kubectl config set-context demouser@kubernetes  \
  --cluster=kubernetes \
  --user=demouser \
  --kubeconfig=demouser.conf


#There's a cluster, a user, and a context defined
kubectl config view --kubeconfig=demouser.conf


#Set the current-context in the kubeconfig file
#Set the context in the file this is a per kubeconfig file setting
kubectl config use-context demouser@kubernetes --kubeconfig=demouser.conf

kubectl create deployment nginx --image=nginx -v 6


#Test the connection using our demouser kubeconfig file. This user is view only.
#Notice which kubeconfig file was loaded demouser.conf and it will use the default context in the kubeconfig file
kubectl get pods --kubeconfig=demouser.conf -v 6


#Since this user is bound to the view ClusterRole, it cannot change or delete objects
kubectl scale deployment nginx --replicas=2 --kubeconfig=demouser.conf


#In addition to using --kubeconfig you can set your current kubeconfig with the KUBECONFIG enviroment variable
#This is useful for switching between kubeconfig files
export KUBECONFIG=demouser.conf
kubectl get pods -v 6
unset KUBECONFIG

# 4 - Let's create a new linux user (-m creates the home director) and then create a new kubeconfig for that user
sudo useradd -m demouser


#Copy the demouser.conf kubeconfig to the home directory of demo user in the default kubeconfig location of .kube/config
sudo mkdir -p /home/demouser/.kube
sudo cp -i demouser.conf /home/demouser/.kube/config
sudo chown -R demouser:demouser /home/demouser/.kube/


#Switch over to this demo user
sudo su demouser 
cd 


#Check out the kubeconf file, we don't need --kubeconfig since it's in the default location  ~/.kube/config
kubectl config view

kubectl create deployment nginx --image=nginx --namespace ns1


#Create a Role, apiGroup is '' since a Pod is in core. Resources (pods) will need to be plural.
kubectl create role demorole --verb=get,list --resource=pods --namespace ns1 --dry-run=client -o yaml
kubectl create role demorole --verb=get,list --resource=pods --namespace ns1


#Create a RoleBinding, defining which user can access the resources defined in the Role demorole
#This is the user we created together in the module Managing certicates and kubeconfig Files.
kubectl create rolebinding demorolebinding --role=demorole --user=demouser --namespace ns1  --dry-run=client -o yaml
kubectl create rolebinding demorolebinding --role=demorole --user=demouser --namespace ns1


#Testing access to resources using can-i and using impersonation...this is a great way to test your rbac configuration
kubectl auth can-i list pods                        #yes, runs as kubernetes-admin
kubectl auth can-i list pods        --as=demouser   #no, runs as demouser, but wrong namespace
kubectl auth can-i list pods        --as=demouser --namespace ns1 #yes, runs as demo user which has rights within the ns1 namespace
kubectl auth can-i list deployments --as=demouser --namespace ns1 #no, runs as demouser, but user cannot get/list deployments...just pods


#Get all the pods in our deployment AS our demouser
kubectl get pods -l app=nginx --namespace ns1 --as=demouser


#Let's try to delete a pod using our user demouser that can only get/list pods in the ns1 namespace
#The user demouser does not have the permissions to delete a pod, this will fail
PODNAME=$(kubectl get pods -l app=nginx --as=demouser --namespace ns1 -o jsonpath='{ .items[*].metadata.name }')
echo $PODNAME
kubectl delete pod $PODNAME --namespace ns1 --as=demouser

kubectl get deployments --namespace ns1 --as=demouser
kubectl auth can-i list nodes --as=demouser #no
kubectl get nodes --as=demouser 


#To give this user access to the node information, we can use a clusterrole and clusterrolebinding
kubectl create clusterrole democlusterrole --verb=get,list --resource=nodes


#Create a ClusterRoleBinding, allowing the user to read Node information
kubectl create clusterrolebinding democlusterrolebinding --clusterrole=democlusterrole --user=demouser
kubectl auth can-i list nodes --as=demouser #yes
kubectl get nodes --as=demouser 




#3 - Using ClusterRole/RoleBinding - to give a user access to more than one namespace
#Let's now create a new namespace and a deployment and try to access that deployment with our user...it will fail
kubectl create namespace ns2    #runs as kubernetes-admin
kubectl create deployment nginx2 --image=nginx --namespace ns2    #runs as kubernetes-admin
kubectl get deployment --as=demouser --namespace ns2


#Rather than maintain the role in the demorole Role in each namespace, let's delete that RoleBinding and Role from the first demo
# and use a ClusterRole and RoleBinding for access to resources in  ns1 and ns2 namespaces for our demouser
kubectl delete rolebinding demorolebinding --namespace ns1
kubectl delete role demorole --namespace ns1


#Create a ClusterRole to be used on both namespaces enabling this user to get/list pods in both namespaces
kubectl create clusterrole democlusterrolepods --verb=get,list --resource=pods


#Create a RoleBinding in each namespace referring to the ClusterRole we just created
#The name can be the same since the rolebinding is in each namespace
#This gives our demouser access to get/list pods in each namespace
kubectl create rolebinding demorolebindingpods --clusterrole=democlusterrolepods  --user=demouser --namespace ns1
kubectl create rolebinding demorolebindingpods --clusterrole=democlusterrolepods  --user=demouser --namespace ns2


#Can we read from both namespaces with our demouser?
kubectl auth can-i list pods --as=demouser --namespace ns1 #Yes
kubectl auth can-i list pods --as=demouser --namespace ns2 #Yes

kubectl get pods --as=demouser --namespace ns1
kubectl get pods --as=demouser --namespace ns2

kubectl create role demoroledeployment --verb=* --resource=deployments --namespace ns1


#Now let's create a rolebinding for this user to the newly created role
kubectl create rolebinding demorolebindingdeployment \
    --role=demoroledeployment --user=demouser --namespace ns1


#Testing out our rights as demouser, rather than impersenation let's switch over to th euser we created in 
#the module 'Managing Certifcates and kubeconfig Files'
sudo su demouser
kubectl get deployment --namespace ns1


#Let's get a listing of pods in the namespace. 
#We still have rights to the pods too because of the ClusterRole/RoleBinding from our third demo in this series of demos
#Where we defined a ClusterRole and added it to RoleBindings in both namespaces.
#This is an example of additive rights, this user is in more than one Role/ClusterRole and gets rights to all the defined resources
kubectl get pods --namespace ns1


#demouser now has full control over the deployment so we can update the image
kubectl describe deployment nginx --namespace ns1 #no image tag specified
kubectl set image deployment nginx nginx=nginx:1.19.1 --namespace ns1
kubectl describe deployment nginx --namespace ns1


#This user cannot list the deployments in ns2, but has rights to the pods in ns2 due the ClusterRole/Rolebinding demo 2.
kubectl get deployment --namespace ns2
kubectl get pods --namespace ns2

#Clean up the user we createing the module 3 demos (or not you can keep it around)
sudo userdel --remove demouser

```
########################################################################  
### API Objects 
######################################################################## 

```
#API Discovery
#Get information about our current cluster context, ensure we're logged into the correct cluster.
kubectl config get-contexts


#Change our context if needed by specifying the Name
kubectl config use-context kubernetes-admin@kubernetes


#Get information about the API Server for our current context, which should be kubernetes-admin@kubernetes
kubectl cluster-info


#Get a list of API Resources available in the cluster
kubectl api-resources | more
kubectl explain pod.spec.containers | more

kubectl apply -f deployment.yaml --dry-run=server
#Use kubectl dry-run client to generate some yaml...for an object
kubectl create deployment nginx --image=nginx --dry-run=client


#Combine dry-run client with -o yaml and you'll get the YAML for the object...in this case a deployment
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml | more
kubectl run pod nginx-pod --image=nginx --dry-run=client -o yaml | more

#Diff that with a deployment with 5 replicas and a new container image...you will see other metadata about the object output too.
kubectl diff -f deployment-new.yaml | more

kubectl api-resources --api-group=apps
kubectl explain deployment --api-version apps/v1 | more
kubectl api-versions | sort | more

kubectl logs hello-world -v 6

#Start kubectl proxy, we can access the resource URL directly.
kubectl proxy &
curl http://localhost:8001/api/v1/namespaces/default/pods/hello-world/log 

#Let's specify a container name and access the consumer container in our Pod
kubectl exec -it multicontainer-pod --container consumer -- /bin/sh
ls -la /usr/share/nginx/html
tail /usr/share/nginx/html/index.html
exit

#This application listens on port 80, we'll forward from 8080->80
kubectl port-forward multicontainer-pod 8080:80 &
curl http://localhost:8080

kubectl exec -it hello-world-onfailure-pod -- /usr/bin/killall hello-app

#get a list of all the API resources and if they can be in a namespace
kubectl api-resources --namespaced=true | head
kubectl api-resources --namespaced=false | head

kubectl get pods --show-labels

#Look at one Pod's labels in our cluster
kubectl describe pod nginx-pod-1 | head

#Query labels and selectors
kubectl get pods --selector tier=prod
kubectl get pods --selector tier=qa
kubectl get pods -l tier=prod
kubectl get pods -l tier=prod --show-labels

#Selector for multiple labels and adding on show-labels to see those labels in the output
kubectl get pods -l 'tier=prod,app=MyWebApp' --show-labels
kubectl get pods -l 'tier=prod,app!=MyWebApp' --show-labels
kubectl get pods -l 'tier in (prod,qa)'
kubectl get pods -l 'tier notin (prod,qa)'

#Output a particluar label in column format
kubectl get pods -L tier
kubectl get pods -L tier,app

#Edit an existing label
kubectl label pod nginx-pod-1 tier=non-prod --overwrite
kubectl get pod nginx-pod-1 --show-labels

#Adding a new label
kubectl label pod nginx-pod-1 another=Label
kubectl get pod nginx-pod-1 --show-labels

#Removing an existing label
kubectl label pod nginx-pod-1 another-
kubectl get pod nginx-pod-1 --show-labels

#Performing an operation on a collection of pods based on a label query
kubectl label pod --all tier=non-prod --overwrite
kubectl get pod --show-labels

#Delete all pods matching our non-prod label
kubectl delete pod -l tier=non-prod

#And we're left with nothing.
kubectl get pods --show-labels

kubectl describe replicaset hello-world

#The Pods have labels for app=hello-world and for the pod-temlpate-hash of the current ReplicaSet
kubectl get pods --show-labels

#Edit the label on one of the Pods in the ReplicaSet, change the pod-template-hash
kubectl label pod PASTE_POD_NAME_HERE pod-template-hash=DEBUG --overwrite

#The ReplicaSet will deploy a new Pod to satisfy the number of replicas. Our relabeled Pod still exists.
kubectl get pods --show-labels

#Let's look at how Services use labels and selectors, check out services.yaml
kubectl get service
kubectl describe service hello-world 
kubectl get pod -o wide

#To remove a pod from load balancing, change the label used by the service's selector.
#The ReplicaSet will respond by placing another pod in the ReplicaSet
kubectl get pods --show-labels
kubectl label pod PASTE_POD_NAME_HERE app=DEBUG --overwrite

#Check out all the labels in our pods
kubectl get pods --show-labels

#Look at the registered endpoint addresses. Now there's 4
kubectl describe endpoints hello-world


#Label our nodes with something descriptive
kubectl label node c1-node2 disk=local_ssd
kubectl label node c1-node3 hardware=local_gpu

#Query our labels to confirm.
kubectl get node -L disk,hardware
#View the scheduling of the pods in the cluster.
kubectl get node -L disk,hardware
kubectl get pods -o wide

#Clean up when we're finished, delete our labels and Pods
kubectl label node c1-node2 disk-
kubectl label node c1-node3 hardware-
```
