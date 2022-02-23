ssh aen@c1-cp1
cd ~/content/course/03/demo


#Accessing information with jsonpath
#Create a workload and scale it
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0
kubectl scale  deployment hello-world --replicas=3
kubectl get pods -l app=hello-world


#We're working with the json output of our objects, in this case pods
#Let's start by accessing that list of Pods, inside items.
#Look at the items, find the metadata and name sections in the json output
kubectl get pods -l app=hello-world -o json > pods.json 


#It's a list of objects, so let's display the pod names
kubectl get pods -l app=hello-world -o jsonpath='{ .items[*].metadata.name }'


#Display all pods names, this will put the new line at the end of the set rather then on each object output to screen.
#Additional tips on formatting code in the examples below including adding a new line after each object
kubectl get pods -l app=hello-world -o jsonpath='{ .items[*].metadata.name }{"\n"}'


#It's a list of objects, so let's display the first (zero'th) pod from the output
kubectl get pods -l app=hello-world -o jsonpath='{ .items[0].metadata.name }{"\n"}'


#Get all container images in use by all pods in all namespaces
kubectl get pods --all-namespaces -o jsonpath='{ .items[*].spec.containers[*].image }{"\n"}'




#Filtering a specific value in a list
#Let's say there's an list inside items and you need to access an element in that list...
#  ?() - defines a filter
#  @ - the current object
kubectl get nodes c1-cp1 -o json | more
#Get all Internal IP Addresses of Nodes in a cluster
kubectl get nodes -o jsonpath="{.items[*].status.addresses[?(@.type=='InternalIP')].address}"



#Sorting
#Use the --sort-by parameter and define which field you want to sort on. It can be any field in the object.
kubectl get pods -A -o jsonpath='{ .items[*].metadata.name }{"\n"}' --sort-by=.metadata.name


#Now that we're sorting that output, maybe we want a listing of all pods sorted by a field that's part of the 
#object but not part of the default kubectl output. like creationTimestamp and we want to see what that value is
#We can use a custom colume to output object field data, in this case the creation timestamp
kubectl get pods -A -o jsonpath='{ .items[*].metadata.name }{"\n"}' \
    --sort-by=.metadata.creationTimestamp \
    --output=custom-columns='NAME:metadata.name,CREATIONTIMESTAMP:metadata.creationTimestamp'


#Clean up our resources
kubectl delete deployment hello-world 



####Additional examples including formatting and sorting examples####

#Let's use the range operator to print a new line for each object in the list
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'


#Combining more than one piece of data, we can use range again to help with this
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{.spec.containers[*].image}{"\n"}{end}'


#All container images across all pods in all namespaces
#Range iterates over a list performing the formatting operations on each element in the list
#We can also add in a sort on the container image name
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' \
    --sort-by=.spec.containers[*].image


#We can use range again to clean up the output if we want
kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="Hostname")].address}{"\n"}{end}'


#We used --sortby when looking at Events earlier, let's use it for another something else now...
#Let's take our container image output from above and sort it
kubectl get pods -A -o jsonpath='{ .items[*].spec.containers[*].image }' --sort-by=.spec.containers[*].image
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name }{"\t"}{.spec.containers[*].image }{"\n"}{end}' --sort-by=.spec.containers[*].image


#Adding in a spaces or tabs in the output to make it a bit more readable
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[*].image}{"\n"}{end}'
kubectl get pods -l app=hello-world -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
