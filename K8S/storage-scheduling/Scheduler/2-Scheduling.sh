#Log into the Control Plane Node to drive these demos.
ssh aen@c1-cp1
cd ~/content/course/04/demos

#Demo - Using Labels to Schedule Pods to Nodes
#The code is below to experiment with on your own. 
# Course: Managing the Kubernetes API Server and Pods
# Module: Managing Objects with Labels, Annotations, and Namespaces
# Clip:   Demo: Services, Labels, Selectors, and Scheduling Pods to Nodes




#Demo 1a - Using Affinity and Anti-Affinity to schedule Pods to Nodes
#Let's start off with a deployment of web and cache pods
#Affinity: we want to have always have a cache pod co-located on a Node where we a Web Pod
kubectl apply -f deployment-affinity.yaml


#Let's check out the labels on the nodes, look for kubernetes.io/hostname which
#we're using for our topologykey
kubectl describe nodes c1-node1 | head
kubectl get nodes --show-labels


#We can see that web and cache are both on the name node
kubectl get pods -o wide 


#If we scale the web deployment
#We'll still get spread across nodes in the ReplicaSet, so we don't need to enforce that with affinity
kubectl scale deployment hello-world-web --replicas=2
kubectl get pods -o wide 


#Then when we scale the cache deployment, it will get scheduled to the same node as the other web server
kubectl scale deployment hello-world-cache --replicas=2
kubectl get pods -o wide 


#Clean up the resources from these deployments
kubectl delete -f deployment-affinity.yaml




#Demo 1b - Using anti-affinity 
#Now, let's test out anti-affinity, deploy web and cache again. 
#But this time we're going to make sure that no more than 1 web pod is on each node with anti-affinity
kubectl apply -f deployment-antiaffinity.yaml
kubectl get pods -o wide


#Now let's scale the replicas in the web and cache deployments
kubectl scale deployment hello-world-web --replicas=4


#One Pod will go Pending because we can have only 1 Web Pod per node 
#when using requiredDuringSchedulingIgnoredDuringExecution in our antiaffinity rule
kubectl get pods -o wide --selector app=hello-world-web


#To 'fix' this we can change the scheduling rule to preferredDuringSchedulingIgnoredDuringExecution
#Also going to set the number of replicas to 4
kubectl apply -f deployment-antiaffinity-corrected.yaml
kubectl scale deployment hello-world-web --replicas=4


#Now we'll have 4 pods up an running, but doesn't the scheduler already ensure replicaset spread? Yes!
kubectl get pods -o wide --selector app=hello-world-web


#Let's clean up the resources from this demos
kubectl delete -f deployment-antiaffinity-corrected.yaml




#Demo 2 - Controlling Pods placement with Taints and Tolerations
#Let's add a Taint to c1-node1
kubectl taint nodes c1-node1 key=MyTaint:NoSchedule


#We can see the taint at the node level, look at the Taints section
kubectl describe node c1-node1


#Let's create a deployment with three replicas
kubectl apply -f deployment.yaml


#We can see Pods get placed on the non tainted nodes
kubectl get pods -o wide


#But we we add a deployment with a Toleration...
kubectl apply -f deployment-tolerations.yaml


#We can see Pods get placed on the non tainted nodes
kubectl get pods -o wide


#Remove our Taint
kubectl taint nodes c1-node1 key:NoSchedule-


#Clean up after our demo
kubectl delete -f deployment-tolerations.yaml
kubectl delete -f deployment.yaml




#Demo - Using Labels to Schedule Pods to Nodes
#From: 
# Course: Managing the Kubernetes API Server and Pods
# Module: Managing Objects with Labels, Annotations, and Namespaces
# Clip:   Demo: Services, Labels, Selectors, and Scheduling Pods to Nodes


#Scheduling a pod to a node
kubectl get nodes --show-labels 


#Label our nodes with something descriptive
kubectl label node c1-node2 disk=local_ssd
kubectl label node c1-node3 hardware=local_gpu


#Query our labels to confirm.
kubectl get node -L disk,hardware


#Create three Pods, two using nodeSelector, one without.
kubectl apply -f DeploymentsToNodes.yaml


#View the scheduling of the pods in the cluster.
kubectl get node -L disk,hardware
kubectl get pods -o wide


#If we scale this Deployment, all new Pods will go onto the node with the GPU label
kubectl scale deployment hello-world-gpu --replicas=3 
kubectl get pods -o wide 


#If we scale this Deployment, all new Pods will go onto the node with the SSD label
kubectl scale deployment hello-world-ssd --replicas=3 
kubectl get pods -o wide 


#If we scale this Deployment, all new Pods will go onto the node without the labels to keep the load balanced
kubectl scale deployment hello-world --replicas=3
kubectl get pods -o wide 


#If we go beyond that...it will use all node to keep load even globally
kubectl scale deployment hello-world --replicas=10
kubectl get pods -o wide 


#Clean up when we're finished, delete our labels and Pods
kubectl label node c1-node2 disk-
kubectl label node c1-node3 hardware-
kubectl delete deployments.apps hello-world
kubectl delete deployments.apps hello-world-gpu
kubectl delete deployments.apps hello-world-ssd