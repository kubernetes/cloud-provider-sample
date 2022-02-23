ssh aen@c1-cp1
cd ~/content/course/04/demo/ 


#1 - Troubleshooting Pods
#Create the deployment we want to troubleshoot
kubectl apply -f deployment-1.yaml

#Scenario:
#You get a call from a user that says none of their pods are up and running can you help?

#Start troubleshooting...

#If no pods are up and running we need to find out why...
#No pods are Ready...0/3. 
kubectl get deployment


#If no pods are running let's look at the pods more closely
kubectl get pods 


#It's a bad image (Status is ErrImagePull or ImagePullBackOff)...
#This means are image isn't available or we have a config issue in our deployment
#Check out the events for more information:
#Failed to pull image "gcr.io/google-samples/hello-ap:1.0": rpc error: code = Unknown desc = Error response from daemon: manifest for gcr.io/google-samples/hello-ap:1.0 not found
#It's hello-ap rather than hello-app. 
kubectl describe pods 


#We can also look at the events to get this information
kubectl get events --sort-by='.metadata.creationTimestamp'


#DECLARATIVE SOLUTION:
#Apply the corrected manifest which points to the correct image
kubectl apply -f deployment-1-corrected.yaml


#IMPERATIVE SOLUTION:
#Change:       - image: gcr.io/google-samples/hello-ap:1.0
#To:           - image: gcr.io/google-samples/hello-app:1.0
kubectl edit deployment hello-world-1


#3 of 3 should be up and ready!
kubectl get deployment


#Clean up this demo before moving on.
kubectl delete -f deployment-1-corrected.yaml





#2 - Troubleshooting Deployments
#Create the deployment we want to troubleshoot
kubectl apply -f deployment-2.yaml

#Scenario:
#You get a call...the pods are up but none are reporting 'Ready' and the app isn't accesible.

#Start troubleshooting by looking at why the Pods aren't Ready...all pods are 0/1 Ready meaning the container in the pod isn't ready.
kubectl get pods 


#We can look at kubectl describe  to quickly find out why?  In the Events you see the readiness probe is failing...but why?
#What port is the Container Port? What is the Port configured in the Readiness Probe? Do they match?
#Readiness probe failed: Get http://192.168.222.225:8081/index.html: dial tcp 192.168.222.225:8081: connect: connection refused
kubectl describe pods 


#DECLARATIVE SOLUTION:
#Deploy the corrected readiness probe
#This will cause a rollout since the pod spec changed.
kubectl apply -f deployment-2-corrected.yaml


#IMPERATIVE SOLUTION:
#This will cause a rollout since the pod spec changed.
#In the readinessProbe
#CHANGE:             port: 8081
#To:                 port: 8080
kubectl edit deployment hello-world-2


#Check the Pods, all should be 1/1 Ready.
kubectl get pods


#Clean up this demo
kubectl delete -f deployment-2-corrected.yaml




#3 - Storage - Failure to access persistant volume storage
#You'll need the NFS server that we configured in the course 'Configuring and Managing Kubernetes Storage and Scheduling' for this demo

#Create the deployment we want to troubleshoot
kubectl apply -f deployment-3.yaml

#Scenario:
#You get a call...the pod is scheduled but it is stuck in ContainerCreating Status

#Start troubleshooting...by check out the Pods state...ContainerCreated...ok let's check out the events
kubectl get pods 


#Events show the error coming from the kubelet on the Node, you'll see that it said 'No such file or directory' 
#Warning  FailedMount  34s  kubelet, c1-node3  MountVolume.SetUp failed for volume "pv-nfs-data" : mount failed: exit status 32
#mount.nfs: mounting 172.16.94.5:/export/volumes/po failed, reason given by server: No such file or directory
kubectl describe pods 


#We can also look at the events to get this information
kubectl get events --sort-by='.metadata.creationTimestamp'


#Deploy the fix which points to the correct nfs export, 172.16.94.5:/export/volumes/pod
#DECLARATIVE SOLUTION: 
kubectl apply -f deployment-3-corrected.yaml

#(No IMPERATIVE SOLUTION for this one)

#That won't work...The PVC gets bound to the bad PV so delete the existing deployment, PVC and PV and then deploy the corrected manifest.
kubectl delete -f deployment-3.yaml


#Deploy the fix again
kubectl apply -f deployment-3-corrected.yaml


#This should be up and Running
kubectl get pods 


#Clean up this demo
kubectl delete -f deployment-3-corrected.yaml



#4 - Scheduling
#Create the deployment we want to troubleshoot
kubectl apply -f deployment-4.yaml

#Scenario: User reports that some pods have started and some have not

#Start troubleshooting...check out the pods
#3 of the 6 pods are pending...why? We should look at the scheduler
kubectl get pods -o wide


#Get scheduler events...scroll up do you see any errors?
#Look for Warnings and Failures...
#0/4 nodes are available: 1 node(s) had taint {node-role.kubernetes.io/master: }, that the pod didn't tolerate, 3 Insufficient cpu
kubectl get events --sort-by='.metadata.creationTimestamp'


#Let's check out the Pods...what are the CPU Requests? It's current set to 1. How many CPUs are allocatable on the Node? Let's look at the Node for that
kubectl describe pods


#Check out the details of the Node to see it's resource allocations and current requests
#How much CPU is Allocatable:? Should be 2 if you're using our lab cluster. 
#How much CPU is Allocated? 1250m or 1.25vCPU...we're out of CPU to allocate on the nodes and the three pending pods cannot start up.
kubectl describe nodes


#DECLARATIVE SOLUTION:
#We can either add more CPUs to the cluster or adjust the requests in our Pod Spec.
#Let's change the request to 500m or 1/2 a CPU. All pods should start
kubectl apply -f deployment-4-corrected.yaml


#IMPERATIVE SOLUTION:
#In Pod.Spec.Container.Resources.Requests
#CHANGE:             cpu: "1"
#TO:                 cpu: "500m"
kubectl edit deployment hello-world-4 


#6 of 6 pods should be online...this start a rollout because the Pod Spec is updated
kubectl get pods 


#Let's clean up this demo
kubectl delete -f deployment-4-corrected.yaml


#5 - Services - mismatching service selector and labels
#Create the deployment we want to troubleshoot
kubectl apply -f deployment-5.yaml

#Scenario: Pods are all online but users cannot connect to the service

#Start troubleshooting...let's see if we can access the service

#Get the Service's ClusterIP and store that for reuse.
SERVICEIP=$(kubectl get service hello-world-5 -o jsonpath='{ .spec.clusterIP }')
echo $SERVICEIP


#Access the service inside the cluster...connection refused...why?
curl http://$SERVICEIP


#Let's check out the endpoints behind the service...there's no endpoints. Why? 
kubectl describe service hello-world-5
kubectl get endpoints hello-world-5


#Let's check the labels and selectors for the service and the pods
#The selector for the service is Selector:  app=hello-world...now let's check the labels on the Pods
kubectl describe service hello-world-5


#Do any of the labels match the selector for the service? 
#No, the labels on the pods are app=hello-world-5 and the selector is app=hello-world
kubectl get pods --show-labels


#DECLARATIVE SOLUTION:
#We can edit the selector or change the labels...let's change the service selector so the pods don't need to restart
kubectl apply -f deployment-5-corrected.yaml


#IMPERATIVE SOLUTION:
#CHANGE:  selector:
#    app: hello-world
#TO:  selector:
#    app: hello-world-5
kubectl edit service hello-world-5


#We should have endpoints
kubectl get endpoints hello-world-5


#Let's access the service, does it work?
SERVICEIP=$(kubectl get service hello-world-5 -o jsonpath='{ .spec.clusterIP }')
curl http://$SERVICEIP



#Clean up this demo
kubectl delete -f deployment-5-corrected.yaml


