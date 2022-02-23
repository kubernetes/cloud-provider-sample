ssh aen@c1-master1
cd ~/content/course/04/demos


#1 - Role/RoleBinding
#Create a service account that can read the API
kubectl create namespace ns1
kubectl create deployment nginx --image=nginx --namespace ns1


#Create a Role, apiGroup is '' since a Pod is in core. Resources (pods) will need to be plural.
kubectl create role demorole --verb=get,list --resource=pods --namespace ns1 --dry-run=client -o yaml
kubectl create role demorole --verb=get,list --resource=pods --namespace ns1


#Create a RoleBinding, defining which user can access the resources defined in the Role demorole
#This is the user we created together in the module Managing certicates and kubeconfig Files.
kubectl create rolebinding demorolebinding --role=demorole --user=demouser --namespace ns1  --dry-run=client -o yaml
kubectl create rolebinding demorolebinding --role=demorole --user=demouser --namespace ns1


#Testing access to resources using can-i and using impersonation...this is a great way to test your rbac configuration
kubectl auth can-i list pods                        #yes, runs as kubernetes-admin
kubectl auth can-i list pods        --as=demouser   #no, runs as demouser, but wrong namespace
kubectl auth can-i list pods        --as=demouser --namespace ns1 #yes, runs as demo user which has rights within the ns1 namespace
kubectl auth can-i list deployments --as=demouser --namespace ns1 #no, runs as demouser, but user cannot get/list deployments...just pods


#Get all the pods in our deployment AS our demouser
kubectl get pods -l app=nginx --namespace ns1 --as=demouser


#Let's try to delete a pod using our user demouser that can only get/list pods in the ns1 namespace
#The user demouser does not have the permissions to delete a pod, this will fail
PODNAME=$(kubectl get pods -l app=nginx --as=demouser --namespace ns1 -o jsonpath='{ .items[*].metadata.name }')
echo $PODNAME
kubectl delete pod $PODNAME --namespace ns1 --as=demouser


#Since this user has only get and list pods, if we try to access another resource with this service account it will fail
#Let's hold onto this user configuration a little longer and we'll adjust its rights to control that deployment
kubectl get deployments --namespace ns1 --as=demouser




#2 - ClusterRole/ClusterRoleBinding
#Create a ClusterRole to access cluster wide/non-namespaced resources
#Goal is to give demouser access to a cluster-wide resource, nodes.
kubectl auth can-i list nodes --as=demouser #no
kubectl get nodes --as=demouser 


#To give this user access to the node information, we can use a clusterrole and clusterrolebinding
kubectl create clusterrole democlusterrole --verb=get,list --resource=nodes


#Create a ClusterRoleBinding, allowing the user to read Node information
kubectl create clusterrolebinding democlusterrolebinding --clusterrole=democlusterrole --user=demouser
kubectl auth can-i list nodes --as=demouser #yes
kubectl get nodes --as=demouser 




#3 - Using ClusterRole/RoleBinding - to give a user access to more than one namespace
#Let's now create a new namespace and a deployment and try to access that deployment with our user...it will fail
kubectl create namespace ns2    #runs as kubernetes-admin
kubectl create deployment nginx2 --image=nginx --namespace ns2    #runs as kubernetes-admin
kubectl get deployment --as=demouser --namespace ns2


#Rather than maintain the role in the demorole Role in each namespace, let's delete that RoleBinding and Role from the first demo
# and use a ClusterRole and RoleBinding for access to resources in  ns1 and ns2 namespaces for our demouser
kubectl delete rolebinding demorolebinding --namespace ns1
kubectl delete role demorole --namespace ns1


#Create a ClusterRole to be used on both namespaces enabling this user to get/list pods in both namespaces
kubectl create clusterrole democlusterrolepods --verb=get,list --resource=pods


#Create a RoleBinding in each namespace referring to the ClusterRole we just created
#The name can be the same since the rolebinding is in each namespace
#This gives our demouser access to get/list pods in each namespace
kubectl create rolebinding demorolebindingpods --clusterrole=democlusterrolepods  --user=demouser --namespace ns1
kubectl create rolebinding demorolebindingpods --clusterrole=democlusterrolepods  --user=demouser --namespace ns2


#Can we read from both namespaces with our demouser?
kubectl auth can-i list pods --as=demouser --namespace ns1 #Yes
kubectl auth can-i list pods --as=demouser --namespace ns2 #Yes

kubectl get pods --as=demouser --namespace ns1
kubectl get pods --as=demouser --namespace ns2




#4 - Giving a user full access to deployments
#Let's give demouser access to the deployments in the ns1 namespace
#The * will give the user full control over the resource, in this case deployments using a Role/RoleBinding
kubectl create role demoroledeployment --verb=* --resource=deployments --namespace ns1


#Now let's create a rolebinding for this user to the newly created role
kubectl create rolebinding demorolebindingdeployment \
    --role=demoroledeployment --user=demouser --namespace ns1


#Testing out our rights as demouser, rather than impersenation let's switch over to th euser we created in 
#the module 'Managing Certifcates and kubeconfig Files'
sudo su demouser
kubectl get deployment --namespace ns1


#Let's get a listing of pods in the namespace. 
#We still have rights to the pods too because of the ClusterRole/RoleBinding from our third demo in this series of demos
#Where we defined a ClusterRole and added it to RoleBindings in both namespaces.
#This is an example of additive rights, this user is in more than one Role/ClusterRole and gets rights to all the defined resources
kubectl get pods --namespace ns1


#demouser now has full control over the deployment so we can update the image
kubectl describe deployment nginx --namespace ns1 #no image tag specified
kubectl set image deployment nginx nginx=nginx:1.19.1 --namespace ns1
kubectl describe deployment nginx --namespace ns1


#This user cannot list the deployments in ns2, but has rights to the pods in ns2 due the ClusterRole/Rolebinding demo 2.
kubectl get deployment --namespace ns2
kubectl get pods --namespace ns2


#log out as demouser
exit





#Clean up this demo
kubectl delete clusterrole democlusterrole
kubectl delete clusterrole democlusterrolepods
kubectl delete clusterrolebinding democlusterrolebinding
kubectl delete namespace ns1
kubectl delete namespace ns2


#Clean up the user we createing the module 3 demos (or not you can keep it around)
sudo userdel --remove demouser
