ssh aen@c1-cp1
cd ~/content/course/03/demo


#Get the Metrics Server deployment manifest from github, the release version may change
#Check here for newer versions --->  https://github.com/kubernetes-sigs/metrics-server
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.7/components.yaml


#Add these two lines to metrics server's container args, around line 90
# - --kubelet-insecure-tls
# - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname


#Deploy the manifest for the Metrics Server
kubectl apply -f components.yaml


#Is the Metrics Server running?
kubectl get pods --namespace kube-system


#Let's test it to see if it's collecting data, we can get core information about memory and CPU.
#This can take a second...
kubectl top nodes


#If you have any issues check out the logs for the metric server...
kubectl logs --namespace kube-system -l k8s-app=metrics-server


#Let's check the perf data for pods, but there's no pods in the default namespace
kubectl top pods 


#We can look at our system pods, CPU and memory 
kubectl top pods --all-namespaces


#Let's deploy a pod that will burn a lot of CPU, but single threaded we have two vCPUs in our nodes.
kubectl apply -f cpuburner.yaml


#And create a deployment and scale it.
kubectl create deployment nginx --image=nginx
kubectl scale  deployment nginx --replicas=3


#Are our pods up and running?
kubectl get pods -o wide


#How about that CPU now, one of the nodes should have about 50% CPU, one should be 1000m+  Recall 1000m = 1vCPU.
#We can see the resource allocations across the nodes in terms of CPU and memory.
kubectl top nodes


#Let's get the perf across all pods...it can take a second after the deployments are create to get data
kubectl top pods 


#We can use labels and selectors to query subsets of pods
kubectl top pods -l app=cpuburner


#And we have primitive sorting, top CPU and top memory consumers across all Pods
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory


#Now, that cpuburner, let's look a little more closely at it we can ask for perf for the containers inside a pod
kubectl top pods --containers



#Clean up  our resources
kubectl delete deployment cpuburner
kubectl delete deployment nginx


#Delete the Metrics Server and it's configuration elements
kubectl delete -f components.yaml
