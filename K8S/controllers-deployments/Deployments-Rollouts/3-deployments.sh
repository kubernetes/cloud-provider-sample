ssh aen@c1-cp1
cd ~/content/course/03/demos/

#Demo 1 - Creating and Scaling a Deployment.
#Let's start off imperatively creating a deployment and scaling it...
#To create a deployment, we need kubectl create deployment
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0


#Check out the status of our deployment, we get 1 Replica
kubectl get deployment hello-world


#Let's scale our deployment from 1 to 10 replicas
kubectl scale deployment hello-world --replicas=10


#Check out the status of our deployment, we get 10 Replicas
kubectl get deployment hello-world


#But we're going to want to use declarative deployments in yaml, so let's delete this.
kubectl delete deployment hello-world


#Deploy our Deployment via yaml, look inside deployment.yaml first.
kubectl apply -f deployment.yaml 


#Check the status of our deployment
kubectl get deployment hello-world


#Apply a modified yaml file scaling from 10 to 20 replicas.
diff deployment.yaml deployment.20replicas.yaml
kubectl apply -f deployment.20replicas.yaml


#Check the status of the deployment
kubectl get deployment hello-world


#Check out the events...the replicaset is scaled to 20
kubectl describe deployment 


#Clean up from our demos
kubectl delete deployment hello-world
kubectl delete service hello-world
