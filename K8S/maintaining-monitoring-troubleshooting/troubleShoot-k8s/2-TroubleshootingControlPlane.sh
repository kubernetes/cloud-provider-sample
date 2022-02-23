ssh aen@c1-cp1
cd ~/content/course/04/demo/ 

#1 - Control Plane Pods Stopped
#Remember the Control Plane Node still has a kubelet and runs pods...if the kubelet's not running then troubleshoot that first.
#This section focuses on the control plane when it's running the control plane as pods
#Run this script on your Control Plane Node node to break the control plane
sh ./2-TroubleshootingControlPlaneBreakStuff-1.sh


#Let's check the status of our control plane pods...refused?
#It can take a a bit to break the control plane wait until it connection to server was refused
kubectl get pods --namespace kube-system


#Let's ask our container runtime, what's up...well there's pods running on this node, but no control plane pods.
#That's your clue...no control plane pods running...what starts up the control plane pods...static pod manifests
sudo docker ps
#If you are using containerd
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps


#Let's check config.yaml for the location of the static pod manifests
#Look for staticPodPath
#Do the yaml files exist at that location?
sudo more /var/lib/kubelet/config.yaml


#The directory doesn't exist...oh no!
sudo ls -laR /etc/kubernetes/manifests


#Let's look up one directory...
sudo ls -la /etc/kubernetes/


#We could update config.yaml to point to this path or rename it to put the manifests in the configured location.
#The kubelet will find these manifests and launch the pods again.
sudo mv /etc/kubernetes/manifests.wrong /etc/kubernetes/manifests
sudo ls /etc/kubernetes/manifests/



#Check the container runtime to ensure the pods are started...we can see they were created and running just a few seconds ago
sudo docker ps 
#If you are using containerd
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps


#Let's ask kubernetes whats it thinks...
kubectl get pods -n kube-system 



#2 - Troubleshooting control plane failure, user Pods are all pending.

#Break the control plane
sh 2-TroubleshootingControlPlaneBreakStuff-2.sh


#Let's start a workload
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=4


#Interesting, all of the pods are pending...why?
kubectl get pods 


#Nodes look good? Yes, they're all reporting ready.
kubectl get nodes


#let's look at the pods' events...<none> nothing, no scheduling, no image pulling, no container starting...let's zoom out
kubectl describe pods 


#What's the next step after the pods are created by the replication controler? Scheduling...
kubectl get events --sort-by='.metadata.creationTimestamp'


#So we know there's no scheduling events, let's check the control plane status...the scheduler isn't listening
#Update: get componentstatuses is deprecated in 1.19+, let's look at the control plane pod's status
#kubectl get componentstatuses 
kubectl get pods --namespace=kube-system -l tier=control-plane


#Ah, the scheduler pod is reporting ImagePullBackoff/ErrImagePull
kubectl get pods --namespace kube-system


#Let's check the events on that pod...we can see if failed fo pull the image for the scheduler, says image not found.
#Looks like the manifest is trying to pull an image that doesn't exist
kubectl describe pods --namespace kube-system kube-scheduler-c1-cp1


#That's defined in the static pod manifest
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml


#Is the scheduler back online, yes, it's running 
kubectl get pods --namespace kube-system


#Update: get componentstatuses is deprecated in 1.19+, let's look at the pod's status
#kubectl get componentstatuses 
kubectl get pods --namespace=kube-system -l tier=control-plane


#And our deployment is now up and running...might take a minute or two for the pods to start up.
kubectl get deployment


#Clean up our resources...
kubectl delete deployments.apps nginx 
