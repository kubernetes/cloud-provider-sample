#Log into the Control Plane Node to drive these demos.
ssh aen@c1-cp1
cd ~/content/course/03/demos


#Demo 1 - Creating and accessing Secrets
#Generic - Create a secret from a local file, directory or literal value
#They keys and values are case sensitive
kubectl create secret generic app1 \
    --from-literal=USERNAME=app1login \
    --from-literal=PASSWORD='S0methingS@Str0ng!'


#Opaque means it's an arbitrary user defined key/value pair. Data 2 means two key/value pairs in the secret.
#Other types include service accounts and container registry authentication info
kubectl get secrets


#app1 said it had 2 Data elements, let's look
kubectl describe secret app1


#If we need to access those at the command line...
#These are wrapped in bash expansion to add a newline to output for readability
echo $(kubectl get secret app1 --template={{.data.USERNAME}} )
echo $(kubectl get secret app1 --template={{.data.USERNAME}} | base64 --decode )

echo $(kubectl get secret app1 --template={{.data.PASSWORD}} )
echo $(kubectl get secret app1 --template={{.data.PASSWORD}} | base64 --decode )




#Demo 2 - Accessing Secrets inside a Pod
#As environment variables
kubectl apply -f deployment-secrets-env.yaml


PODNAME=$(kubectl get pods | grep hello-world-secrets-env | awk '{print $1}' | head -n 1)
echo $PODNAME


#Now let's get our enviroment variables from our container
kubectl exec -it $PODNAME -- /bin/sh
printenv | grep ^app1
exit


#Accessing Secrets as files
kubectl apply -f deployment-secrets-files.yaml


#Grab our pod name into a variable
PODNAME=$(kubectl get pods | grep hello-world-secrets-files | awk '{print $1}' | head -n 1)
echo $PODNAME


#Looking more closely at the Pod we see volumes, appconfig and in Mounts...
kubectl describe pod $PODNAME


#Let's access a shell on the Pod
kubectl exec -it $PODNAME -- /bin/sh


#Now we see the path we defined in the Volumes part of the Pod Spec
#A directory for each KEY and it's contents are the value
ls /etc/appconfig
cat /etc/appconfig/USERNAME
cat /etc/appconfig/PASSWORD
exit


#If you need to put only a subset of the keys in a secret check out this line here and look at items
#https://kubernetes.io/docs/concepts/storage/volumes#secret


#let's clean up after our demos...
kubectl delete secret app1
kubectl delete deployment hello-world-secrets-env
kubectl delete deployment hello-world-secrets-files




#Additional examples of using secrets in your Pods
#I'll leave this up to you to work with...
#Create a secret using clear text and the stringData field
kubectl apply -f secret.string.yaml


#Create a secret with encoded values, preferred over clear text.
echo -n 'app2login' | base64
echo -n 'S0methingS@Str0ng!' | base64
kubectl apply -f secret.encoded.yaml


#Check out the list of secrets now available 
kubectl get secrets

#examine how each object is stored, look at the annotations for the app2 secret.
kubectl get secrets app2 -o yaml
kubectl get secrets app3 -o yaml

#There's also an envFrom example in here for you too...
kubectl create secret generic app1 --from-literal=USERNAME=app1login --from-literal=PASSWORD='S0methingS@Str0ng!'


#Create the deployment, envFrom will create enviroment variables for each key in the named secret app1 with and set it's value set to the secrets value
kubectl apply -f deployment-secrets-env-from.yaml

PODNAME=$(kubectl get pods | grep hello-world-secrets-env-from | awk '{print $1}' | head -n 1)
echo $PODNAME 
kubectl exec -it $PODNAME -- /bin/sh
printenv | sort
exit


kubectl delete secret app1
kubectl delete secret app2
kubectl delete secret app3
kubectl delete deployment hello-world-secrets-env-from
