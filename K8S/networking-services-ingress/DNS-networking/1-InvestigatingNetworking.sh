#1 - Investigating Kubernetes Networking
#Log into our local cluster
ssh aen@c1-cp1
cd ~/content/course/02/demos



#Local Cluster - Calico CNI Plugin
#Get all Nodes and their IP information, INTERNAL-IP is the real IP of the Node
kubectl get nodes -o wide


#Let's deploy a basic workload, hello-world with 3 replicas to create some pods on the pod network.
kubectl apply -f Deployment.yaml


#Get all Pods, we can see each Pod has a unique IP on the Pod Network.
#Our Pod Network was defined in the first course and we chose 192.168.0.0/16
kubectl get pods -o wide


#Let's hop inside a pod and check out it's networking, a single interface an IP on the Pod Network
#The line below will get a list of pods from the label query and return the name of the first pod in the list
PODNAME=$(kubectl get pods --selector=app=hello-world -o jsonpath='{ .items[0].metadata.name }')
echo $PODNAME
kubectl exec -it $PODNAME -- /bin/sh
ip addr
exit


#For the Pod on c1-node1, let's find out how traffic gets from c1-cp1 to c1-node1 to get to that Pod.

#Look at the annotations, specifically the annotation projectcalico.org/IPv4IPIPTunnelAddr: 192.168.19.64...your IP may vary
#Check out the Addresses: InternalIP, that's the real IP of the Node.
# Pod IPs are allocated from the network Pod Network which is configurable in Calico, it's controlling the IP allocation.
# Calico is using a tunnel interfaces to implement the Pod Network model. 
# Traffic going to other Pods will be sent into the tunnel interface and directly to the Node running the Pod.
# For more info on Calico's operations https://docs.projectcalico.org/reference/cni-plugin/configuration
kubectl describe node c1-cp1 | more


#Let's see how the traffic gets to c1-node1 from c1-cp1
#Via routes on the node, to get to c1-node1 traffic goes into tunl0/192.168.19.64...your IP may vary
#Calico handles the tunneling and sends the packet to the correct node to be send on into the Pod running on that Node based on the defined routes
#Follow each route, showing how to get to the Pod IP, it will need to go to the tun0 interface.
#There cali* interfaces are for each Pod on the Pod network, traffic destined for the Pod IP will have a 255.255.255.255 route to this interface.
kubectl get pods -o wide
route


#The local tunl0 is 192.168.19.64, packets destined for Pods running on c1-cp1 will be routed to this interface and get encapsulated
#Then send to the destination node for de-encapsulation.
ip addr


#Log into c1-node1 and look at the interfaces, there's tunl0 192.168.222.192...this is this node's tunnel interface
ssh aen@c1-node1


#This tunl0 is the destination interface, on this Node its 192.168.222.192, which we saw on the route listing on c1-cp1
ip addr


#All Nodes will have routes back to the other Nodes via the tunl0 interface
route


#Exit back to c1-cp1
exit







#Azure Kubernetes Service - kubenet
#Get all Nodes and their IP information, INTERNAL-IP is the real IP of the Node
kubectl config use-context 'CSCluster'


#Let's deploy a basic workload, hello-world with 3 replicas.
kubectl apply -f Deployment.yaml

#Note the INTERNAL-IP, these are on the virtual network in Azure, the real IPs of the underlying VMs
kubectl get nodes -o wide


#This time we're using a different network plugin, kubenet. It's based on routes/bridges rather than tunnels. Let's explore
#Check out Addresses and PodCIDR
kubectl describe nodes | more


#The Pods are getting IPs from their Node's PodCIDR Range
kubectl get pods -o wide


#Access an AKS Node via SSH so we can examine it's network config which uses kubenet
#https://docs.microsoft.com/en-us/azure/aks/ssh#configure-virtual-machine-scale-set-based-aks-clusters-for-ssh-access
NODENAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl debug node/$NODENAME -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11


#Check out the routes, notice the route to the local Pod Network matching PodCIDR for this Node sending traffic to cbr0
#The routes for the other PodCIDR ranges on the other Nodes are implemented in the cloud's virtual network. 
route


#In Azure, these routes are implemented as route tables assigned to the virtual machine's for your Nodes.
#You'll find the routes implemented in the Resource Group as a Route Table assigned to the subnet the Nodes are on.
#This is a link to my Azure account, your's will vary.
#https://portal.azure.com/#@nocentinohotmail.onmicrosoft.com/resource/subscriptions/fd0c5e48-eea6-4b37-a076-0e23e0df74cb/resourceGroups/mc_kubernetes-cloud_cscluster_centralus/providers/Microsoft.Network/routeTables/aks-agentpool-89481420-routetable/overview

#Check out the eth0, actual Node interface IP, then cbr0 which is the bridge the Pods are attached to and 
#has an IP on the Pod Network.
#Each Pod has an veth interface on the bridge, which you see here, and and interface inside the container
#which will have the Pod IP.
ip addr 


#Let's check out the bridge's 'connections'
brctl show


#Exit the container on the node
exit


#Here is the Pod's interface and it's IP. 
#This interface is attached to the cbr0 bridge on the Node to get access to the Pod network. 
PODNAME=$(kubectl get pods -o jsonpath='{ .items[0].metadata.name }')
kubectl exec -it $PODNAME -- ip addr


#And inside the pod, there's a default route in the pod to the interface 10.244.0.1 which is the brige interface cbr0.
#Then the Node will route it on the Node network for reachability to other nodes.
kubectl exec -it $PODNAME -- route


#Delete the deployment in AKS, switch to the local cluster and delete the deployment too. 
kubectl delete -f Deployment.yaml 
kubectl config use-context kubernetes-admin@kubernetes
kubectl delete -f Deployment.yaml 
