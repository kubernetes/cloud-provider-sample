ssh aen@c1-cp1
cd ~/content/course/03/demo


#1 - Pods
#Check the logs for a single container pod.
kubectl create deployment nginx --image=nginx
PODNAME=$(kubectl get pods -l app=nginx -o jsonpath='{ .items[0].metadata.name }')
echo $PODNAME
kubectl logs $PODNAME


#Clean up that deployment
kubectl delete deployment nginx


#Let's create a multi-container pod that writes some information to stdout
kubectl apply -f multicontainer.yaml


#Pods a specific container in a Pod and a collection of Pods
PODNAME=$(kubectl get pods -l app=loggingdemo -o jsonpath='{ .items[0].metadata.name }')
echo $PODNAME


#Let's get the logs from the multicontainer pod...this will throw an error and ask us to define which container
kubectl logs $PODNAME


#But we need to specify which container inside the pods
kubectl logs $PODNAME -c container1
kubectl logs $PODNAME -c container2


#We can access all container logs which will dump each containers in sequence
kubectl logs $PODNAME --all-containers


#If we need to follow a log, we can do that...helpful in debugging real time issues
#This works for both single and multi-container pods
kubectl logs $PODNAME --all-containers --follow
ctrl+c


#For all pods matching the selector, get all the container logs and write it to stdout and then file
kubectl get pods --selector app=loggingdemo
kubectl logs --selector app=loggingdemo --all-containers 
kubectl logs --selector app=loggingdemo --all-containers  > allpods.txt


#Also helpful is tailing the bottom of a log...
#Here we're getting the last 5 log entries across all pods matching the selector
#You can do this for a single container or using a selector
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



#3 - Control plane
#Get a listing of the control plane pods using a selector
kubectl get pods --namespace kube-system --selector tier=control-plane


#We can retrieve the logs for the control plane pods by using kubectl logs
#This info is coming from the API server over kubectl, 
#it instructs the kubelet will read the log from the node and send it back to you over stdout
kubectl logs --namespace kube-system kube-apiserver-c1-cp1  


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
 

#Create a flawed deployment
kubectl create deployment nginx --image ngins


#We can filter the list of events using field selector
kubectl get events --field-selector type=Warning
kubectl get events --field-selector type=Warning,reason=Failed


#We can also monitor the events as they happen with watch
kubectl get events --watch &
kubectl scale deployment loggingdemo --replicas=5


#break out of the watch
fg
ctrl+c


#We can look in another namespace too if needed.
kubectl get events --namespace kube-system


#These events are also available in the object as part of kubectl describe, in the events section
kubectl describe deployment nginx
kubectl describe replicaset nginx-7df5f8b5cb #Update to your replicaset name
kubectl describe pods nginx


#Clean up our resources
kubectl delete -f multicontainer.yaml
kubectl delete deployment nginx


#But the event data is still availble from the cluster's events, even though the objects are gone.
kubectl get events --sort-by='.metadata.creationTimestamp'
