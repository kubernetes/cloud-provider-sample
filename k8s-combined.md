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

### DaemonSet

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

### Jobs

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

