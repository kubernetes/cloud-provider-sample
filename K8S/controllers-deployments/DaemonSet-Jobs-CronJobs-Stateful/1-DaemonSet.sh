ssh aen@c1-cp1
cd ~/content/course/04/demos


#Demo 1 - Creating a DaemonSet on All Nodes
#We get one Pod per Node to run network services on that Node
kubectl get nodes
kubectl get daemonsets --namespace kube-system kube-proxy


#Let's create a DaemonSet with Pods on each node in our cluster...that's NOT the Control Plane Node
kubectl apply -f DaemonSet.yaml


#So we'll get three since we have 3 workers and 1 Control Plane Node in our cluster and the Control Plane Node is set to run only system pods
kubectl get daemonsets
kubectl get daemonsets -o wide
kubectl get pods -o wide


#Callout, labels, Desired/Current Nodes Scheduled. Pod Status and Template and Events.
kubectl describe daemonsets hello-world | more 


#Each Pods is created with our label, app=hello-world, controller-revision-hash and a pod-template-generation
kubectl get pods --show-labels


#If we change the label to one of our Pods...
MYPOD=$(kubectl get pods -l app=hello-world-app | grep hello-world | head -n 1 | awk {'print $1'})
echo $MYPOD
kubectl label pods $MYPOD app=not-hello-world --overwrite


#We'll get a new Pod from the DaemonSet Controller
kubectl get pods --show-labels

#Let's clean up this DaemonSet
kubectl delete daemonsets hello-world-ds
kubectl delete pods $MYPOD



#Demo 2 - Creating a DaemonSet on a Subset of Nodes
#Let's create a DaemonSet with a defined nodeSelector
kubectl apply -f DaemonSetWithNodeSelector.yaml


#No pods created because we don't have any nodes with the appropriate label
kubectl get daemonsets


#We need a Node that satisfies the Node Selector
kubectl label node c1-node1 node=hello-world-ns


#Let's see if a Pod gets created...
kubectl get daemonsets
kubectl get daemonsets -o wide
kubectl get pods -o wide

#What's going to happen if we remove the label
kubectl label node c1-node1 node-


#It's going to terminate the Pod, examine events, Desired Number of Nodes Scheduled...
kubectl describe daemonsets hello-world-ds


#Clean up our demo
kubectl delete daemonsets hello-world-ds



#Demo 3 - Updating a DaemonSet
#Deploy our v1 DaemonSet again
kubectl apply -f DaemonSet.yaml


#Check out our image version, 1.0
kubectl describe daemonsets hello-world


#Examine what our update stategy is...defaults to rollingUpdate and maxUnavailable 1
kubectl get DaemonSet hello-world-ds -o yaml | more


#Update our container image from 1.0 to 2.0 and apply the config
diff DaemonSet.yaml DaemonSet-v2.yaml
kubectl apply -f DaemonSet-v2.yaml


#Check on the status of our rollout, a touch slower than a deployment due to maxUnavailable.
kubectl rollout status daemonsets hello-world-ds


#We can see our DaemonSet Container Image is now 2.0 and in the Events that it rolled out.
kubectl describe daemonsets

#we can see the new controller-revision-hash and also an updated pod-template-generation
kubectl get pods --show-labels


#Time to clean up our demos
kubectl delete daemonsets hello-world-ds

