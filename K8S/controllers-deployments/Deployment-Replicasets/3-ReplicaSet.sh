#Log into the Control Plane Node to drive these demos.
ssh aen@c1-cp1
cd ~/content/course/02/demos


#Demo 1 - Deploy a Deployment which creates a ReplicaSet
kubectl apply -f deployment.yaml
kubectl get replicaset


#Let's look at the selector for this one...and the labels in the pod template
kubectl describe replicaset hello-world


#Let's delete this deployment which will delete the replicaset
kubectl delete deployment hello-world
kubectl get replicaset



#Deploy a ReplicaSet with matchExpressions
kubectl apply -f deployment-me.yaml


#Check on the status of our ReplicaSet
kubectl get replicaset


#Let's look at the Selector for this one...and the labels in the pod template
kubectl describe replicaset hello-world


#Demo 2 - Deleting a Pod in a ReplicaSet, application will self-heal itself
kubectl get pods
kubectl delete pods hello-world-[tab][tab]
kubectl get pods




#Demo 3 - Isolating a Pod from a ReplicaSet
#For more coverage on this see, Managing the Kubernetes API Server and Pods - Module 2 - Managing Objects with Labels, Annotations, and Namespaces
kubectl get pods --show-labels


#Edit the label on one of the Pods in the ReplicaSet, the replicaset controller will create a new pod
kubectl label pod hello-world-[tab][tab] app=DEBUG --overwrite
kubectl get pods --show-labels




#Demo 4 - Taking over an existing Pod in a ReplicaSet, relabel that pod to bring 
#it back into the scope of the replicaset...what's kubernetes going to do?
kubectl label pod hello-world-[tab][tab] app=hello-world-pod-me --overwrite


#One Pod will be terminated, since it will maintain the desired number of replicas at 5
kubectl get pods --show-labels
kubectl describe ReplicaSets




#Demo 5 - Node failures in ReplicaSets
#Shutdown a node
ssh c1-node3
sudo shutdown -h now


#c1-node3 Status Will go NotReady...takes about 1 minute.
kubectl get nodes --watch


#But there's a Pod still on c1-node3...wut? 
#Kubernetes is protecting against transient issues. Assumes the Pod is still running...
kubectl get pods -o wide


#Start up c1-node3, break out of watch when Node reports Ready, takes about 15 seconds
kubectl get nodes --watch


#That Pod that was on c1-node3 goes to Status Error then it will be restarted on that Node.
kubectl get pods -o wide 


#It will start the container back up on the Node c1-node3...see Restarts is now 1, takes about 10 seconds
#The pod didn't get rescheduled, it's still there, the container restart policy restarts the container which 
#starts at 10 seconds and defaults to Always. We covered this in detail in my course "Managing the Kuberentes API Server and Pods"
kubectl get pods -o wide --watch

#Shutdown a node again...
ssh c1-node3
sudo shutdown -h now


#Let's set a watch and wait...about 5 minutes and see what kubernetes will do.
#Because of the --pod-eviction-timeout duration setting on the kube-controller-manager, this pod will get killed after 5 minutes.
kubectl get pods --watch


#Orphaned Pod goes Terminating and a new Pod will be deployed in the cluster.
#If the Node returns the Pod will be deleted, if the Node does not, we'll have to delete it
kubectl get pods -o wide


#And go start c1-node3 back up again and see if those pods get deleted :)


#let's clean up...
kubectl delete deployment hello-world
kubectl delete service hello-world
