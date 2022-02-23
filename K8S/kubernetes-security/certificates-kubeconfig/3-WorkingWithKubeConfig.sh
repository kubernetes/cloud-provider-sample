ssh aen@c1-master1
cd ~/content/course/03/demos



#1 - Working with kubeconfig files and contexts
#Investigating your kubeconfig file, this came from /etc/kubernetes/admin.conf 
#When you used kubeadm to build your cluster you then copied admin.conf from /etc/kubernetes to ~/.kube/config
kubectl config view
kubectl config view --raw
more ~/.kube/config


#Add a new context from Azure Kubernetes Service
#See Kubernetes Installation and Configuration Fundamentals to create an AKS Cluster
az aks get-credentials --resource-group "Kubernetes-Cloud" --name CSCluster


#List our currently available contexts
kubectl config get-contexts


#set our current context to the Azure context
kubectl config use-context CSCluster


#run a command to communicate with our cluster.
kubectl cluster-info


#set our current context to the local cluster context
kubectl config use-context kubernetes-admin@kubernetes
kubectl cluster-info


#To delete kubeconfig entries
kubectl config delete-context CSCluster
kubectl config delete-cluster CSCluster
kubectl config unset users.clusterUser_Kubernetes-Cloud_CSCluster




#2 - Creating a kubeconfig file for a new read only user. 
#We'll be using our certificate and key from the last demo
#demouser.key and demouser.crt

#This could be a role, but I'm choosing the view ClusterRole here for read only access
kubectl create clusterrolebinding demouserclusterrolebinding \
  --clusterrole=view --user=demouser


#Create the cluster entry, notice the kubeconfig parameter, this will generate a new file using that name.
# embed-certs puts the cert data in the kubeconfig entry for this user
kubectl config set-cluster kubernetes-demo \
  --server=https://172.16.94.10:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --kubeconfig=demouser.conf


#There's a new kubeconfig file in the current working directory
ls demouser.conf


#Let's confirm the cluster is create in there.
kubectl config view --kubeconfig=demouser.conf


#Add user to new kubeconfig file demouser.conf
#Keep in mind there's several authentication methods, we're focusing on certificates here
kubectl config set-credentials demouser \
  --client-key=demouser.key \
  --client-certificate=demouser.crt \
  --embed-certs=true \
  --kubeconfig=demouser.conf


#Now we have a Cluster and a User
kubectl config view --kubeconfig=demouser.conf


#Add the context, context name, cluster name, user name
kubectl config set-context demouser@kubernetes-demo  \
  --cluster=kubernetes-demo \
  --user=demouser \
  --kubeconfig=demouser.conf


#There's a cluster, a user, and a context defined
kubectl config view --kubeconfig=demouser.conf


#Set the current-context in the kubeconfig file
#Set the context in the file this is a per kubeconfig file setting
kubectl config use-context demouser@kubernetes-demo --kubeconfig=demouser.conf




#3 - Using a new kubeconfig file for a new user
#Create a workload...this is being executed as our normal admin user (kubernetes-admin)!
#Notice in the output it's loading our ~/.kube/config
kubectl create deployment nginx --image=nginx -v 6


#Test the connection using our demouser kubeconfig file. This user is view only.
#Notice which kubeconfig file was loaded demouser.conf and it will use the default context in the kubeconfig file
kubectl get pods --kubeconfig=demouser.conf -v 6


#Since this user is bound to the view ClusterRole, it cannot change or delete objects
kubectl scale deployment nginx --replicas=2 --kubeconfig=demouser.conf


#In addition to using --kubeconfig you can set your current kubeconfig with the KUBECONFIG enviroment variable
#This is useful for switching between kubeconfig files
export KUBECONFIG=demouser.conf
kubectl get pods -v 6
unset KUBECONFIG




# 4 - Let's create a new linux user (-m creates the home director) and then create a new kubeconfig for that user
sudo useradd -m demouser


#Copy the demouser.conf kubeconfig to the home directory of demo user in the default kubeconfig location of .kube/config
sudo mkdir -p /home/demouser/.kube
sudo cp -i demouser.conf /home/demouser/.kube/config
sudo chown -R demouser:demouser /home/demouser/.kube/


#Switch over to this demo user
sudo su demouser 
cd 


#Check out the kubeconf file, we don't need --kubeconfig since it's in the default location  ~/.kube/config
kubectl config view


#Test access as our new user, check where the config loaded from. Are there pods in the output?
kubectl get pods -v 6


#Change back to our regular user
exit



#Keep demouser.conf around for the demos in the next module on Role Based Access Controls.
#This user is currently only view, in the next module we'll adjust its RBAC rules to edit the deployment
#But let's delete that deployment
kubectl delete deployment nginx

###Be sure to delete the clusterrolebinding we created in step 2####
kubectl delete clusterrolebinding demouserclusterrolebinding
