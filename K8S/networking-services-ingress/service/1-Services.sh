ssh aen@c1-cp1
cd ~/content/course/03/demos/

#1 - Exposing and accessing applications with Services on our local cluster
#ClusterIP

#Imperative, create a deployment with one replica
kubectl create deployment hello-world-clusterip \
    --image=gcr.io/google-samples/hello-app:1.0


#When creating a service, you can define a type, if you don't define a type, the default is ClusterIP
kubectl expose deployment hello-world-clusterip \
    --port=80 --target-port=8080 --type ClusterIP


#Get a list of services, examine the Type, CLUSTER-IP and Port
kubectl get service


#Get the Service's ClusterIP and store that for reuse.
SERVICEIP=$(kubectl get service hello-world-clusterip -o jsonpath='{ .spec.clusterIP }')
echo $SERVICEIP


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


#Access the service inside the cluster, this time our requests will be load balanced...whooo!
curl http://$SERVICEIP


#The Service's Endpoints match the labels, let's look at the service and it's selector and the pods labels.
kubectl describe service hello-world-clusterip
kubectl get pods --show-labels


#Clean up these resources for the next demo
kubectl delete deployments hello-world-clusterip
kubectl delete service hello-world-clusterip




#2 - Creating a NodePort Service
#Imperative, create a deployment with one replica
kubectl create deployment hello-world-nodeport \
    --image=gcr.io/google-samples/hello-app:1.0


#When creating a service, you can define a type, if you don't define a type, the default is ClusterIP
kubectl expose deployment hello-world-nodeport \
    --port=80 --target-port=8080 --type NodePort


#Let's check out the services details, there's the Node Port after the : in the Ports column. It's also got a ClusterIP and Port
#This NodePort service is available on that NodePort on each node in the cluster
kubectl get service


CLUSTERIP=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.clusterIP }')
PORT=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.ports[].port }')
NODEPORT=$(kubectl get service hello-world-nodeport -o jsonpath='{ .spec.ports[].nodePort }')

#Let's access the services on the Node Port...we can do that on each node in the cluster and 
#from outside the cluster...regardless of where the pod actually is

#We have only one pod online supporting our service
kubectl get pods -o wide


#And we can access the service by hitting the node port on ANY node in the cluster on the Node's Real IP or Name.
#This will forward to the cluster IP and get load balanced to a Pod. Even if there is only one Pod.
curl http://c1-cp1:$NODEPORT
curl http://c1-node1:$NODEPORT
curl http://c1-node2:$NODEPORT
curl http://c1-node3:$NODEPORT


#And a Node port service is also listening on a Cluster IP, in fact the Node Port traffic is routed to the ClusterIP
echo $CLUSTERIP:$PORT
curl http://$CLUSTERIP:$PORT


#Let's delete that service
kubectl delete service hello-world-nodeport
kubectl delete deployment hello-world-nodeport




#3 - Creating LoadBalancer Services in Azure or any cloud
#Switch contexts into AKS, we created this cluster together in 'Kubernetes Installation and Configuration Fundamentals'
#I've added a script to create a GKE and AKS cluster this course's downloads.
kubectl config use-context 'CSCluster'


#Let's create a deployment
kubectl create deployment hello-world-loadbalancer \
    --image=gcr.io/google-samples/hello-app:1.0


#When creating a service, you can define a type, if you don't define a type, the default is ClusterIP
kubectl expose deployment hello-world-loadbalancer \
    --port=80 --target-port=8080 --type LoadBalancer


#Can take a minute for the load balancer to provision and get an public IP, you'll see EXTERNAL-IP as <pending>
kubectl get service


LOADBALANCERIP=$(kubectl get service hello-world-loadbalancer -o jsonpath='{ .status.loadBalancer.ingress[].ip }')
curl http://$LOADBALANCERIP:$PORT


#The loadbalancer, which is 'outside' your cluster, sends traffic to the NodePort Service which sends it to the ClusterIP to get to your pods!
#Your cloud load balancer will have health probes checking the health of the node port service on the real node IPs.
#This isn't the health of our application, that still needs to be configured via readiness/liveness probes and maintained by your Deployment configuration
kubectl get service hello-world-loadbalancer



#Clean up the resources from this demo
kubectl delete deployment hello-world-loadbalancer
kubectl delete service hello-world-loadbalancer


#Let's switch back to our local cluster
kubectl config use-context kubernetes-admin@kubernetes



#Declarative examples
kubectl config use-context kubernetes-admin@kubernetes
kubectl apply -f service-hello-world-clusterip.yaml
kubectl get service


#Creating a NodePort with a predefined port, first with a port outside of the NodePort range then a corrected one.
kubectl apply -f service-hello-world-nodeport-incorrect.yaml
kubectl apply -f service-hello-world-nodeport.yaml
kubectl get service


#Switch contexts to Azure to create a cloud load balancer
kubectl config use-context 'CSCluster'
kubectl apply -f service-hello-world-loadbalancer.yaml
kubectl get service


#Clean up these resources
kubectl delete -f service-hello-world-loadbalancer.yaml
kubectl config use-context kubernetes-admin@kubernetes
kubectl delete -f service-hello-world-nodeport.yaml
kubectl delete -f service-hello-world-clusterip.yaml
