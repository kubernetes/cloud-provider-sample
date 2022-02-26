## API Objects Deplyments

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

#Using kubectl explain to see the structure of a resource...specifically it's fields
#In addition to using the API reference on the web this is a great way to discover what it takes to write yaml manifests
kubectl explain pods | more

#Let's look more closely at what we need in pod.spec and pod.spec.containers (image and name are required)
kubectl explain pod.spec | more
kubectl explain pod.spec.containers | more

#Working with kubectl dry-run
#Use kubectl dry-run for server side validatation of a manifest...the object will be sent to the API Server.
#dry-run=server will tell you the object was created...but it wasn't...
#it just goes through the whole process but didn't get stored in etcd.
kubectl apply -f deployment.yaml --dry-run=server

#Use kubectl dry-run for client side validatation of a manifest...
kubectl apply -f deployment.yaml --dry-run=client

#Combine dry-run client with -o yaml and you'll get the YAML for the object...in this case a deployment
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml | more

#Can be any object...let's try a pod...
kubectl run pod nginx-pod --image=nginx --dry-run=client -o yaml | more

#Diff that with a deployment with 5 replicas and a new container image...you will see other metadata about the object output too.
kubectl diff -f deployment-new.yaml | more

#Clean up from this demo...you can use delete with -f to delete all the resources in the manifests
kubectl delete -f deployment.yaml

#A list of the objects available in a specific API Group such as apps...try using another API Group...
kubectl api-resources --api-group=apps

#We can use explain to dig further into a specific API Resource and version 
#Check out KIND and VERSION, we'll see the API Group in the from group/version 
#Deployments recently moved from apps/v1beta1 to apps/v1
kubectl explain deployment --api-version apps/v1 | more

#Print the supported API versions and Groups on the API server again in the form group/version.
#Here we see several API Groups have several versions in various stages of release...such as v1, v1beta1, v2beta1...and so on.
kubectl api-versions | sort | more


#We still have our kubectl get events running in the background, so we see if re-create the container automatically.
kubectl exec -it hello-world-pod -- /usr/bin/killall hello-app

#Remember...we can ask the API server what it knows about an object, in this case our restartPolicy
kubectl explain pods.spec.restartPolicy

#get a list of all the API resources and if they can be in a namespace
kubectl api-resources --namespaced=true | head
kubectl api-resources --namespaced=false | head


```

## Anatomy of an API Request
```
#We can use the -v option to increase the verbosity of our request.
#Display requested resource URL. Focus on VERB, API Path and Response code
kubectl get pod hello-world -v 6 

#Same output as 6, add HTTP Request Headers. Focus on application type, and User-Agent
kubectl get pod hello-world -v 7 

#Same output as 7, adds Response Headers and truncated Response Body.
kubectl get pod hello-world -v 8 

#Same output as 8, add full Response. Focus on the bottom, look for metadata
kubectl get pod hello-world -v 9 

#Start up a kubectl proxy session, this will authenticate use to the API Server
#Using our local kubeconfig for authentication and settings, updated head to only return 10 lines.
kubectl proxy &
curl http://localhost:8001/api/v1/namespaces/default/pods/hello-world | head -n 10

fg
ctrl+c

#Watch, Exec and Log Requests
#A watch on Pods will watch on the resourceVersion on api/v1/namespaces/default/Pods
kubectl get pods --watch -v 6 &

#We can see kubectl keeps the TCP session open with the server...waiting for data.
netstat -plant | grep kubectl

#Accessing logs
kubectl logs hello-world -v 6
```

## Scale / PORT_FORWARD / StaticPodPath

```

#Start up kubectl get events --watch and background it.
kubectl get events --watch &

#Scale a Deployment to 2 replicas. We see the scaling the replica set and the replica set starting the second pod
kubectl scale deployment hello-world --replicas=2

#Let's use exec a command inside our container, we can see the GET and POST API requests through the API server to reach the pod.
kubectl -v 6 exec -it PASTE_POD_NAME_HERE -- /bin/sh

#Let's specify a container name and access the consumer container in our Pod
kubectl exec -it multicontainer-pod --container consumer -- /bin/sh

#Now, let's access our Pod's application directly, without a service and also off the Pod network.
kubectl port-forward PASTE_POD_NAME_HERE 80:8080

#Let's do it again, but this time with a non-priviledged port
kubectl port-forward PASTE_POD_NAME_HERE 8080:8080 &

#We can point curl to localhost, and kubectl port-forward will send the traffic through the API server to the Pod
curl http://localhost:8080

#Static pods
#Quickly create a Pod manifest using kubectl run with dry-run and -o yaml...copy that into your clipboard
kubectl run hello-world --image=gcr.io/google-samples/hello-app:2.0 --dry-run=client -o yaml --port=8080 

#Find the staticPodPath:
sudo cat /var/lib/kubelet/config.yaml

#Create a Pod manifest in the staticPod Path...paste in the manifest we created above
sudo vi /etc/kubernetes/manifests/mypod.yaml
ls /etc/kubernetes/manifests
```

## LABELS

```
#Query labels and selectors
kubectl get pods --selector tier=prod
kubectl get pods -l tier=prod --show-labels

#Selector for multiple labels and adding on show-labels to see those labels in the output
kubectl get pods -l 'tier=prod,app=MyWebApp' --show-labels
kubectl get pods -l 'tier=prod,app!=MyWebApp' --show-labels
kubectl get pods -l 'tier in (prod,qa)'
kubectl get pods -l 'tier notin (prod,qa)'

#Output a particluar label in column format
kubectl get pods -L tier,app

#Edit an existing label
kubectl label pod nginx-pod-1 tier=non-prod --overwrite
kubectl get pod nginx-pod-1 --show-labels

#Adding a new label
kubectl label pod nginx-pod-1 another=Label

#Removing an existing label
kubectl label pod nginx-pod-1 another-

#Performing an operation on a collection of pods based on a label query
kubectl label pod --all tier=non-prod --overwrite

#Delete all pods matching our non-prod label
kubectl delete pod -l tier=non-prod

#The ReplicaSet has labels and selectors for app and the current pod-template-hash
#Look at the Pod Template and the labels on the Pods created
kubectl describe replicaset hello-world

#Edit the label on one of the Pods in the ReplicaSet, change the pod-template-hash
kubectl label pod PASTE_POD_NAME_HERE pod-template-hash=DEBUG --overwrite

#The selector for this serivce is app=hello-world, that pod is still being load balanced to!
kubectl describe service hello-world 

#Get a list of all IPs in the service, there's 5...why?
kubectl describe endpoints hello-world

#Scheduling a pod to a node
#Scheduling is a much deeper topic, we're focusing on how labels can be used to influence it here.
kubectl get nodes --show-labels 

#Label our nodes with something descriptive
kubectl label node c1-node2 disk=local_ssd

#Query our labels to confirm.
kubectl get node -L disk,hardware

#Clean up when we're finished, delete our labels and Pods
kubectl label node c1-node2 disk-

```

## DaemonSet

```
kubectl get daemonsets --namespace kube-system kube-proxy

#If we change the label to one of our Pods...
MYPOD=$(kubectl get pods -l app=hello-world-app | grep hello-world | head -n 1 | awk {'print $1'})
echo $MYPOD
kubectl label pods $MYPOD app=not-hello-world --overwrite

#Let's clean up this DaemonSet
kubectl delete daemonsets hello-world-ds

#Check on the status of our rollout, a touch slower than a deployment due to maxUnavailable.
kubectl rollout status daemonsets hello-world-ds

kubectl rollout history deployment hello-world --revision=3

#Let's undo our rollout to revision 2, which is our v2 container.
kubectl rollout undo deployment hello-world --to-revision=2


```

## Jobs

```
#Follow job status with a watch
kubectl get job --watch

#So let's review what the job did...Events, created...then deleted. Pods status, 3 Failed.
kubectl describe jobs | more

#But let's look closer...schedule, Concurrency, Suspend,Starting Deadline Seconds, events...there's execution history
kubectl describe cronjobs | more 

#Get a overview again...
kubectl get cronjobs
```

## Services

```

#Imperative, create a deployment with one replica
kubectl create deployment hello-world-clusterip \
    --image=gcr.io/google-samples/hello-app:1.0


#When creating a service, you can define a type, if you don't define a type, the default is ClusterIP
kubectl expose deployment hello-world-clusterip \
    --port=80 --target-port=8080 --type ClusterIP

#Access the service inside the cluster
curl http://$SERVICEIP

#Get a listing of the endpoints for a service, we see the one pod endpoint registered.
kubectl get endpoints hello-world-clusterip
kubectl get pods -o wide

#Access the pod's application directly on the Target Port on the Pod, not the service's Port, useful for troubleshooting.
#Right now there's only one Pod and its one Endpoint
kubectl get endpoints hello-world-clusterip
PODIP=$(kubectl get endpoints hello-world-clusterip -o jsonpath='{ .subsets[].addresses[].ip }')
echo $PODIP
curl http://$PODIP:8080


#Scale the deployment, new endpoints are registered automatically
kubectl scale deployment hello-world-clusterip --replicas=6
kubectl get endpoints hello-world-clusterip

#When creating a service, you can define a type, if you don't define a type, the default is ClusterIP
kubectl expose deployment hello-world-nodeport \
    --port=80 --target-port=8080 --type NodePort

CLUSTERIP=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.clusterIP }')
PORT=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.ports[].port }')
NODEPORT=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.ports[].nodePort }')

#When creating a service, you can define a type, if you don't define a type, the default is ClusterIP
kubectl expose deployment hello-world-loadbalancer \
    --port=80 --target-port=8080 --type LoadBalancer

LOADBALANCERIP=$(kubectl get service hello-world-loadbalancer -o jsonpath='{ .status.loadBalancer.ingress[].ip }')
curl http://$LOADBALANCERIP:$PORT

#The configmap defining the CoreDNS configuration and we can see the default forwarder is /etc/resolv.conf
kubectl get configmaps --namespace kube-system coredns -o yaml | more

kubectl logs --namespace kube-system --selector 'k8s-app=kube-dns' --follow 

#Run some DNS queries against the kube-dns service cluster ip to ensure everything works...
SERVICEIP=$(kubectl get service --namespace kube-system kube-dns -o jsonpath='{ .spec.clusterIP }')
nslookup www.pluralsight.com $SERVICEIP

PODNAME=$(kubectl get pods --selector=app=hello-world-customdns -o jsonpath='{ .items[0].metadata.name }')
echo $PODNAME
kubectl exec -it $PODNAME -- cat /etc/resolv.conf

#For one of the pods replace the dots in the IP address with dashes for example 192.168.206.68 becomes 192-168-206-68
#We'll look at some additional examples of Service Discovery in the next module too.
nslookup 192-168-206-[xx].default.pod.cluster.local $SERVICEIP

#Find the name of a Node running one of the DNS Pods running...so we're going to observe DNS queries there.
DNSPODNODENAME=$(kubectl get pods --namespace kube-system --selector=k8s-app=kube-dns -o jsonpath='{ .items[0].spec.nodeName }')
echo $DNSPODNODENAME

kubectl describe ingress ingress-single

kubectl create deployment hello-world-service-blue --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment hello-world-service-single --port=80 --target-port=8080 --type=ClusterIP
kubectl get ingress --watch
kubectl get services --namespace ingress-nginx
curl http://$INGRESSIP/red  --header 'Host: path.example.com'
curl http://$INGRESSNODEPORTIP:$NODEPORT/red/1  --header 'Host: path.example.com'
#Access the application via the exposed ingress on the public IP
INGRESSIP=$(kubectl get ingress -o jsonpath='{ .items[].status.loadBalancer.ingress[].ip }')
curl http://$INGRESSIP


#TLS Example
#1 - Generate a certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout tls.key -out tls.crt -subj "/C=US/ST=ILLINOIS/L=CHICAGO/O=IT/OU=IT/CN=tls.example.com"

#2 - Create a secret with the key and the certificate
kubectl create secret tls tls-secret --key tls.key --cert tls.crt

#Test access to the hostname...we need --resolve because we haven't registered the DNS name
#TLS is a layer lower than host headers, so we have to specify the correct DNS name. 
curl https://tls.example.com:443 --resolve tls.example.com:443:$INGRESSIP --insecure --verbose


#Access the application via the exposed ingress that's listening the NodePort and it's static port, let's get some variables so we can reused them
INGRESSNODEPORTIP=$(kubectl get ingresses ingress-single -o jsonpath='{ .status.loadBalancer.ingress[].ip }')
NODEPORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{ .spec.ports[?(@.name=="http")].nodePort }')
echo $INGRESSNODEPORTIP:$NODEPORT
curl http://$INGRESSNODEPORTIP:$NODEPORT

#TLS is a layer lower than host headers, so we have to specify the correct DNS name. 
kubectl get service -n ingress-nginx ingress-nginx-controller
NODEPORTHTTPS=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{ .spec.ports[?(@.name=="https")].nodePort }')
echo $NODEPORTHTTPS
curl https://tls.example.com:$NODEPORTHTTPS/ \
    --resolve tls.example.com:$NODEPORTHTTPS:$INGRESSNODEPORTIP \
    --insecure --verbose

```

## PV, PVC, StorageClass

```
#Review the created resources, Status, Access Mode and Reclaim policy is set to Reclaim rather than Delete. 
kubectl get PersistentVolume pv-nfs-data

#Look more closely at the PV and it's configuration
kubectl describe PersistentVolume pv-nfs-data

#Check the status, Bound.
#We defined the PVC it statically provisioned the PV...but it's not mounted yet.
kubectl get PersistentVolumeClaim pvc-nfs-data
kubectl describe PersistentVolumeClaim pvc-nfs-data

SERVICEIP=$(kubectl get service | grep nginx-nfs-service | awk '{ print $3 }')


#Get a list of the current StorageClasses kubectl get StorageClass.
kubectl get StorageClass

#A closer look at the SC, you can see the Reclaim Policy is Delete since we didn't set it in our StorageClass yaml
kubectl describe StorageClass managed-standard-ssd


```


## Scheduling, UnScheduling

```

#Let's cordon c1-node3
kubectl cordon c1-node3

#c1-node3 won't get any new pods...one of the other Nodes will get an extra Pod here.
kubectl get pods -o wide

#Let's drain (remove) the Pods from c1-node3...
kubectl drain c1-node3 

#Let's try that again since daemonsets aren't scheduled we need to work around them.
kubectl drain c1-node3 --ignore-daemonsets

#We can uncordon c1-node3, but nothing will get scheduled there until there's an event like a scaling operation or an eviction.
#Something that will cause pods to get created
kubectl uncordon c1-node3

```

##  Secrets

```
#Get the new pod name and check the environment variables...the variables are define at Pod/Container startup.
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

#app1 said it had 2 Data elements, let's look
kubectl describe secret app1

#If we need to access those at the command line...
#These are wrapped in bash expansion to add a newline to output for readability
echo $(kubectl get secret app1 --template={{.data.USERNAME}} )
echo $(kubectl get secret app1 --template={{.data.USERNAME}} | base64 --decode )

echo $(kubectl get secret app1 --template={{.data.PASSWORD}} )
echo $(kubectl get secret app1 --template={{.data.PASSWORD}} | base64 --decode )



#Update the paramters to match the information for your repository including the servername, username, password and email.
kubectl create secret docker-registry private-reg-cred \
    --docker-server=https://index.docker.io/v2/ \
    --docker-username=$USERNAME \
    --docker-password=$PASSWORD \
    --docker-email=$EMAIL


#Let's pull down a hello-world image from gcr
sudo ctr images pull gcr.io/google-samples/hello-app:1.0

#Let's get a listing of images from ctr to confim our image is downloaded
sudo ctr images list

#Tagging our image in the format your registry, image and tag
sudo ctr images tag gcr.io/google-samples/hello-app:1.0 docker.io/nocentino/hello-app:ps

sudo ctr images push docker.io/nocentino/hello-app:ps --user $USERNAME

ssh aen@c1-node3 'sudo ctr --namespace k8s.io image ls "name~=hello-app" -q | sudo xargs ctr --namespace k8s.io image rm'

sudo ctr images remove docker.io/nocentino/hello-app:ps

```

## ConfigMaps

```
#Create a PROD ConfigMap
kubectl create configmap appconfigprod \
    --from-literal=DATABASE_SERVERNAME=sql.example.local \
    --from-literal=BACKEND_SERVERNAME=be.example.local

more appconfigqa
kubectl create configmap appconfigqa \
    --from-file=appconfigqa

#Each creation method yeilded a different structure in the ConfigMap
kubectl get configmap appconfigprod -o yaml


```

## ETCD

```
kubectl describe pod etcd-c1-cp1 -n kube-system

#The configuration for etcd comes from the static pod manifest, check out the listen-client-urls, data-dir, volumeMounts, volumes/
sudo more /etc/kubernetes/manifests/etcd.yaml

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

#Run the restore to a second folder...this will restore to the current directory
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/lib/dat-backup.db

#Restart the static pod for etcd...
#if you kubectl delete it will NOT restart the static pod as it's managed by the kubelet not a controller or the control plane.
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps | grep etcd
CONTAINER_ID=$(sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps  | grep etcd | awk '{ print $1 }')
echo $CONTAINER_ID

#Stop the etcd container from our etcd pod and move our restored data into place
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock stop $CONTAINER_ID

kubectl get secret test-secret

#Using the same backup from earlier
#Run the restore to a define data-dir, rather than the current working directory
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/lib/dat-backup.db --data-dir=/var/lib/etcd-restore

#This will cause the control plane pods to restart...let's check it at the container runtime level
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps

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

```

## LOGs & Events

```
#Let's get the logs from the multicontainer pod...this will throw an error and ask us to define which container
kubectl logs $PODNAME

#But we need to specify which container inside the pods
kubectl logs $PODNAME -c container1

#We can access all container logs which will dump each containers in sequence
kubectl logs $PODNAME --all-containers

#If we need to follow a log, we can do that...helpful in debugging real time issues
#This works for both single and multi-container pods
kubectl logs $PODNAME --all-containers --follow
ctrl+c

#For all pods matching the selector, get all the container logs and write it to stdout and then file
kubectl get pods --selector app=loggingdemo
kubectl logs --selector app=loggingdemo --all-containers  > allpods.txt

kubectl logs --selector app=loggingdemo --all-containers --tail 5

#2 - Nodes
#Get key information and status about the kubelet, ensure that it's active/running and check out the log. 
#Also key information about it's configuration is available.
systemctl status kubelet.service

#If we want to examine it's log further, we use journalctl to access it's log from journald
# -u for which systemd unit. If using a pager, use f and b to for forward and back.
journalctl -u kubelet.service

#journalctl has search capabilities, but grep is likely easier
journalctl -u kubelet.service | grep -i ERROR

#Time bounding your searches can be helpful in finding issues add --no-pager for line wrapping
journalctl -u kubelet.service --since today --no-pager

#But, what if your control plane is down? Go to docker or to the file system.
#kubectl logs will send the request to the local node's kubelet to read the logs from disk
#Since we're on the Control Plane Node/control plane node already we can use docker for that.
sudo docker ps

#Grab the log for the api server pod, paste in the CONTAINER ID 
sudo docker ps  | grep k8s_kube-apiserver
CONTAINER_ID=$(sudo docker ps | grep k8s_kube-apiserver | awk '{ print $1 }')
echo $CONTAINER_ID
sudo docker logs $CONTAINER_ID

#But, what if docker is not available?
#They're also available on the filesystem, here you'll find the current and the previous logs files for the containers. 
#This is the same across all nodes and pods in the cluster. This also applies to user pods/containers.
#These are json formmatted which is the docker logging driver default
sudo ls /var/log/containers
sudo tail /var/log/containers/kube-apiserver-c1-cp1*

#4 - Events
#Show events for all objects in the cluster in the default namespace
#Look for the deployment creation and scaling operations from above...
#If you don't have any events since they are only around for an hour create a deployment to generate some
kubectl get events 

#It can be easier if the data is actually sorted...
#sort by isn't for just events, it can be used in most output
kubectl get events --sort-by='.metadata.creationTimestamp'
 
#We can filter the list of events using field selector
kubectl get events --field-selector type=Warning
kubectl get events --field-selector type=Warning,reason=Failed

#We can also monitor the events as they happen with watch
kubectl get events --watch &

#But the event data is still availble from the cluster's events, even though the objects are gone.
kubectl get events --sort-by='.metadata.creationTimestamp'



```

## JSON Filtering

```

#Display all pods names, this will put the new line at the end of the set rather then on each object output to screen.
#Additional tips on formatting code in the examples below including adding a new line after each object
kubectl get pods -l app=hello-world -o jsonpath='{ .items[*].metadata.name }{"\n"}'

#Get all container images in use by all pods in all namespaces
kubectl get pods --all-namespaces -o jsonpath='{ .items[*].spec.containers[*].image }{"\n"}'

#Filtering a specific value in a list
#Let's say there's an list inside items and you need to access an element in that list...
#  ?() - defines a filter
#  @ - the current object
kubectl get nodes c1-cp1 -o json | more
#Get all Internal IP Addresses of Nodes in a cluster
kubectl get nodes -o jsonpath="{.items[*].status.addresses[?(@.type=='InternalIP')].address}"

#Sorting
#Use the --sort-by parameter and define which field you want to sort on. It can be any field in the object.
kubectl get pods -A -o jsonpath='{ .items[*].metadata.name }{"\n"}' --sort-by=.metadata.name

#Now that we're sorting that output, maybe we want a listing of all pods sorted by a field that's part of the 
#object but not part of the default kubectl output. like creationTimestamp and we want to see what that value is
#We can use a custom colume to output object field data, in this case the creation timestamp
kubectl get pods -A -o jsonpath='{ .items[*].metadata.name }{"\n"}' \
    --sort-by=.metadata.creationTimestamp \
    --output=custom-columns='NAME:metadata.name,CREATIONTIMESTAMP:metadata.creationTimestamp'

#Let's use the range operator to print a new line for each object in the list
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

#Combining more than one piece of data, we can use range again to help with this
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{.spec.containers[*].image}{"\n"}{end}'

#All container images across all pods in all namespaces
#Range iterates over a list performing the formatting operations on each element in the list
#We can also add in a sort on the container image name
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' \
    --sort-by=.spec.containers[*].image

#We can use range again to clean up the output if we want
kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="Hostname")].address}{"\n"}{end}'


#We used --sortby when looking at Events earlier, let's use it for another something else now...
#Let's take our container image output from above and sort it
kubectl get pods -A -o jsonpath='{ .items[*].spec.containers[*].image }' --sort-by=.spec.containers[*].image
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name }{"\t"}{.spec.containers[*].image }{"\n"}{end}' --sort-by=.spec.containers[*].image


#Adding in a spaces or tabs in the output to make it a bit more readable
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[*].image}{"\n"}{end}'
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'


```

## Monitoring

```
#Let's test it to see if it's collecting data, we can get core information about memory and CPU.
#This can take a second...
kubectl top nodes

#If you have any issues check out the logs for the metric server...
kubectl logs --namespace kube-system -l k8s-app=metrics-server

#We can look at our system pods, CPU and memory 
kubectl top pods --all-namespaces

#We can use labels and selectors to query subsets of pods
kubectl top pods -l app=cpuburner

#And we have primitive sorting, top CPU and top memory consumers across all Pods
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory

#Now, that cpuburner, let's look a little more closely at it we can ask for perf for the containers inside a pod
kubectl top pods --containers

```

## TroubleShooting 

```
#The kubelet runs as a systemd service/unit...so we can use those tools to troubleshoot why it's not working
#Let's start by checking the status. Add no-pager so it will wrap the text
#It's loaded, but it's inactive (dead)...so that means it's not running. 
#We want the service to be active (running)
#So the first thing to check is the service enabled?
sudo systemctl status kubelet.service

#If the service wasn't configured to start up by default (disabled) we can use enable to set it to.
sudo systemctl enable kubelet.service 

#That just enables the service to start up on boot, we could reboot now or we can start it manually
#So let's start it up and see what happens...ah, it's now actice (running) which means the kubelet is online.
#We also see in the journald snippet, that it's watching the apiserver. So good stuff there...
sudo systemctl start kubelet.service

#Crashlooping kubelet...indicated by the code = exited and the status = 255
#But that didn't tell us WHY the kubelet is crashlooping, just that it is...let's dig deeper
sudo systemctl status kubelet.service --no-pager

#systemd based systems write logs to journald, let's ask it for the logs for the kubelet
#This tells us exactly what's wrong, the failed to load the Kubelet config file 
#which it thinks is at /var/lib/kubelet/config.yaml
sudo journalctl -u kubelet.service --no-pager

#Let's see what's in /var/lib/kubelet/...ah, look the kubelet wants config.yaml, but we have config.yml
sudo ls -la /var/lib/kubelet 

#Let's reconfigure where the kubelet looks for this config file
#Where is the kubelet config file specified?, check the systemd unit config for the kubelet
#Where does systemd think the kubelet's config.yaml is?
sudo systemctl status kubelet.service --no-pager
sudo more /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

#Let's update the config args, inside here is the startup configuration for the kubelet
sudo vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

#Let's restart the kubelet...
sudo systemctl restart kubelet 

#But since we edited the unit file, we neede to reload the unit files (configs)...then restart the service
sudo systemctl daemon-reload
sudo systemctl restart kubelet 

#Check the status...active and running?
sudo systemctl status kubelet.service


#Let's ask our container runtime, what's up...well there's pods running on this node, but no control plane pods.
#That's your clue...no control plane pods running...what starts up the control plane pods...static pod manifests
sudo docker ps
#If you are using containerd
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps

#What's the next step after the pods are created by the replication controler? Scheduling...
kubectl get events --sort-by='.metadata.creationTimestamp'


```

## Authentication

```
kubectl config view --raw

#Let's read the certificate information out of our kubeconfig file
#Look for Subject: CN= is the username which is kubernetes-admin, it's also in the group (O=) system:masters
kubectl config view --raw -o jsonpath='{ .users[*].user.client-certificate-data }' | base64 --decode > admin.crt
openssl x509 -in admin.crt -text -noout | head

#We can use -v 6 to see the api request, and return code which is 200.
kubectl get pods -v 6

#3 - Accessing the API Server inside a Pod
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

```

## Authorization

```
#1 - Changing authorization for a service account
#We left off with where serviceaccount didn't have access to the API Server to access Pods
kubectl auth can-i list pods --as=system:serviceaccount:default:mysvcaccount1

#But we can create an RBAC Role and bind that to our service account
#We define who, can perform what verbs on what resources
kubectl create role demorole --verb=get,list --resource=pods
kubectl create rolebinding demorolebinding --role=demorole --serviceaccount=default:mysvcaccount1 

kubectl get pods -v 6 --as=system:serviceaccount:default:mysvcaccount1

#Load the token and cacert into variables for reuse
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

#Now I can view objects...this isn't just for curl but for any application. 
#Apps commonly use libraries to programmaticly interact with the api server for cluster state information 
curl --cacert $CACERT --header "Authorization: Bearer $TOKEN" -X GET https://kubernetes.default.svc/api/v1/namespaces/default/pods


```

## Creating Certificates

```
#Read the ca.crt to view the certificates information, useful to determine the validity date of the certifcate
#You can use this command to read the information about any of the *.crt in this folder
#Be sure to check out the validity and the Subject CN
openssl x509 -in /etc/kubernetes/pki/ca.crt -text -noout | more


#1 - Create a certificate for a new user
#https://kubernetes.io/docs/concepts/cluster-administration/certificates/#cfssl
#Create a private key
openssl genrsa -out demouser.key 2048

#Generate a CSR
#CN (Common Name) is your username, O (Organization) is the Group
#If you get an error Can't load /home/USERNAME/.rnd into RNG - comment out RANDFILE from /etc/ssl/openssl.conf 
# see this link for more details https://github.com/openssl/openssl/issues/7754#issuecomment-541307674
openssl req -new -key demouser.key -out demouser.csr -subj "/CN=demouser"

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

#Read the certficate itself
#Key elements: Issuer is our CA, Validity one year, Subject CN=demousers
openssl x509 -in demouser.crt -text -noout | head -n 15
```

## KUBECONFIG

```

kubectl config view --raw

#set our current context to the Azure context
kubectl config use-context CSCluster

#run a command to communicate with our cluster.
kubectl cluster-info

#To delete kubeconfig entries
kubectl config delete-context CSCluster
kubectl config delete-cluster CSCluster
kubectl config unset users.clusterUser_Kubernetes-Cloud_CSCluster

#2 - Creating a kubeconfig file for a new read only user. 
#We'll be using our certificate and key from the last demo
#demouser.key and demouser.crt

#This could be a role, but I'm choosing the view ClusterRole here for read only access
kubectl create clusterrolebinding demouserclusterrolebinding \
  --clusterrole=view --user=demouser


#Create the cluster entry, notice the kubeconfig parameter, this will generate a new file using that name.
# embed-certs puts the cert data in the kubeconfig entry for this user
kubectl config set-cluster kubernetes-demo \
  --server=https://172.16.94.10:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --kubeconfig=demouser.conf

#There's a new kubeconfig file in the current working directory
ls demouser.conf

#Add user to new kubeconfig file demouser.conf
#Keep in mind there's several authentication methods, we're focusing on certificates here
kubectl config set-credentials demouser \
  --client-key=demouser.key \
  --client-certificate=demouser.crt \
  --embed-certs=true \
  --kubeconfig=demouser.conf

#Add the context, context name, cluster name, user name
kubectl config set-context demouser@kubernetes-demo  \
  --cluster=kubernetes-demo \
  --user=demouser \
  --kubeconfig=demouser.conf

#Set the current-context in the kubeconfig file
#Set the context in the file this is a per kubeconfig file setting
kubectl config use-context demouser@kubernetes-demo --kubeconfig=demouser.conf

#In addition to using --kubeconfig you can set your current kubeconfig with the KUBECONFIG enviroment variable
#This is useful for switching between kubeconfig files
export KUBECONFIG=demouser.conf
kubectl get pods -v 6
unset KUBECONFIG

```

## RBAC

```
#1 - Role/RoleBinding
#Create a service account that can read the API
kubectl create namespace ns1
kubectl create deployment nginx --image=nginx --namespace ns1

#Create a Role, apiGroup is '' since a Pod is in core. Resources (pods) will need to be plural.
kubectl create role demorole --verb=get,list --resource=pods --namespace ns1 --dry-run=client -o yaml

#Create a RoleBinding, defining which user can access the resources defined in the Role demorole
#This is the user we created together in the module Managing certicates and kubeconfig Files.
kubectl create rolebinding demorolebinding --role=demorole --user=demouser --namespace ns1  --dry-run=client -o yaml

#Testing access to resources using can-i and using impersonation...this is a great way to test your rbac configuration
kubectl auth can-i list pods        --as=demouser --namespace ns1 #yes, runs as demo user which has rights within the ns1 namespace
kubectl auth can-i list deployments --as=demouser --namespace ns1 #no, runs as demouser, but user cannot get/list deployments...just pods

#2 - ClusterRole/ClusterRoleBinding
#Create a ClusterRole to access cluster wide/non-namespaced resources
#Goal is to give demouser access to a cluster-wide resource, nodes.
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

#Create a ClusterRole to be used on both namespaces enabling this user to get/list pods in both namespaces
kubectl create clusterrole democlusterrolepods --verb=get,list --resource=pods

#Can we read from both namespaces with our demouser?
kubectl auth can-i list pods --as=demouser --namespace ns1 #Yes

kubectl get pods --as=demouser --namespace ns1

#4 - Giving a user full access to deployments
#Let's give demouser access to the deployments in the ns1 namespace
#The * will give the user full control over the resource, in this case deployments using a Role/RoleBinding
kubectl create role demoroledeployment --verb=* --resource=deployments --namespace ns1


#Now let's create a rolebinding for this user to the newly created role
kubectl create rolebinding demorolebindingdeployment \
    --role=demoroledeployment --user=demouser --namespace ns1

#demouser now has full control over the deployment so we can update the image
kubectl describe deployment nginx --namespace ns1 #no image tag specified
kubectl set image deployment nginx nginx=nginx:1.19.1 --namespace ns1



```