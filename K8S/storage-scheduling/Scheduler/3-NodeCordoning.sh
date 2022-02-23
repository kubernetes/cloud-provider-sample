#Log into the Control Plane Node to drive these demos.
ssh aen@c1-cp1
cd ~/content/course/04/demos




#Demo 1 - Node Cordoning
#Let's create a deployment with three replicas
kubectl apply -f deployment.yaml


#Pods spread out evenly across the nodes
kubectl get pods -o wide


#Let's cordon c1-node3
kubectl cordon c1-node3


#That won't evict any pods...
kubectl get pods -o wide


#But if I scale the deployment
kubectl scale deployment hello-world --replicas=6


#c1-node3 won't get any new pods...one of the other Nodes will get an extra Pod here.
kubectl get pods -o wide


#Let's drain (remove) the Pods from c1-node3...
kubectl drain c1-node3 


#Let's try that again since daemonsets aren't scheduled we need to work around them.
kubectl drain c1-node3 --ignore-daemonsets


#Now all the workload is on c1-node1 and 2
kubectl get pods -o wide


#We can uncordon c1-node3, but nothing will get scheduled there until there's an event like a scaling operation or an eviction.
#Something that will cause pods to get created
kubectl uncordon c1-node3


#So let's scale that Deployment and see where they get scheduled...
kubectl scale deployment hello-world --replicas=9


#All three get scheduled to the cordoned node
kubectl get pods -o wide


#Clean up this demo...
kubectl delete deployment hello-world




#Demo 2 - Manually scheduling a Pod by specifying nodeName
kubectl apply -f pod.yaml


#Our Pod should be on c1-node3
kubectl get pod -o wide


#Let's delete our pod, since there's no controller it won't get recreated :(
kubectl delete pod hello-world-pod 


#Now let's cordon node3 again
kubectl cordon c1-node3


#And try to recreate our pod
kubectl apply -f pod.yaml


#You can still place a pod on the node since the Pod isn't getting 'scheduled', status is SchedulingDisabled
kubectl get pod -o wide


#Can't remove the unmanaged Pod either since it's not managed by a Controller and won't get restarted
kubectl drain c1-node3 --ignore-daemonsets 


#Let's clean up our demo, delete our pod and uncordon the node
kubectl delete pod hello-world-pod 
 

#Now let's uncordon node3 so it's able to have pods scheduled to it
#I forgot to do this in the video demo :)
kubectl uncordon c1-node3
