ssh aen@c1-cp1
cd ~/content/course/02/demo



#1 - Find the version you want to upgrade to. 
#You can only upgrade one minor version to the next minor version
sudo apt update
apt-cache policy kubeadm


#What version are we on?
kubectl version --short
kubectl get nodes


#First, upgrade kubeadm on the Control Plane Node
#Replace the version with the version you want to upgrade to.
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.19.2-00
sudo apt-mark hold kubeadm


#All good?
kubeadm version


#Next, Drain any workload on the Control Plane Node node
kubectl drain c1-cp1 --ignore-daemonsets


#Run upgrade plan to test the upgrade process and run pre-flight checks
#Highlights additional work needed after the upgrade, such as manually updating the kubelets
#And displays version information for the control plan components
sudo kubeadm upgrade plan


#Run the upgrade, you can get this from the previous output.
#Runs preflight checks - API available, Node status Ready and control plane healthy
#Checks to ensure you're upgrading along the correct upgrade path
#Prepulls container images to reduce downtime of control plane components
#For each control plane component, 
#   Updates the certificates used for authentication
#   Creates a new static pod manifest in /etc/kubernetes/mainifests and saves the old one to /etc/kubernetes/tmp
#   Which causes the kubelet to restart the pods
#Updates the Control Plane Node's kubelet configuration and also updates CoreDNS and kube-proxy
sudo kubeadm upgrade apply v1.19.2  #<---this format is different than the package's version format


#Look for [upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.xx.yy". Enjoy!


#Uncordon the node
kubectl uncordon c1-cp1 


#Now update the kubelet and kubectl on the control plane node(s)
sudo apt-mark unhold kubelet kubectl 
sudo apt-get update
sudo apt-get install -y kubelet=1.19.2-00 kubectl=1.19.2-00
sudo apt-mark hold kubelet kubectl


#Check the update status
kubectl version --short
kubectl get nodes


#Upgrade any additional control plane nodes with the same process.


#Upgrade the workers, drain the node, then log into it. 
#Update the enviroment variable so you can reuse those code over and over.
kubectl drain c1-node[XX] --ignore-daemonsets
ssh aen@c1-node[XX]


#First, upgrade kubeadm 
sudo apt-mark unhold kubeadm 
sudo apt-get update
sudo apt-get install -y kubeadm=1.19.2-00
sudo apt-mark hold kubeadm


#Updates kubelet configuration for the node
sudo kubeadm upgrade node


#Update the kubelet and kubectl on the node
sudo apt-mark unhold kubelet kubectl 
sudo apt-get update
sudo apt-get install -y kubelet=1.19.2-00 kubectl=1.19.2-00
sudo apt-mark hold kubelet kubectl


#Log out of the node
exit


#Get the nodes to show the version...can take a second to update
kubectl get nodes 


#Uncordon the node to allow workload again
kubectl uncordon c1-node[XX]


#check the versions of the nodes
kubectl get nodes


####TO DO###
####BE SURE TO UPGRADE THE REMAINING WORKER NODES#####


#check the versions of the nodes
kubectl get nodes
