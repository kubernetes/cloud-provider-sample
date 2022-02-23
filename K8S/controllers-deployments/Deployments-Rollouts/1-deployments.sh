ssh aen@c1-cp1
cd ~/content/course/03/demos/

#Demo 1 - Updating a Deployment and checking our rollout status
#Let's start off with rolling out v1
kubectl apply -f deployment.yaml


#Check the status of the deployment
kubectl get deployment hello-world


#Now let's apply that deployment, run both this and line 18 at the same time.
kubectl apply -f deployment.v2.yaml


#Let's check the status of that rollout, while the command blocking your deployment is in the Progressing status.
kubectl rollout status deployment hello-world


#Expect a return code of 0 from kubectl rollout status...that's how we know we're in the Complete status.
echo $?


#Let's walk through the description of the deployment...
#Check out Replicas, Conditions and Events OldReplicaSet (will only be populated during a rollout) and NewReplicaSet
#Conditions (more information about our objects state):
#     Available      True    MinimumReplicasAvailable
#     Progressing    True    NewReplicaSetAvailable (when true, deployment is still progressing or complete)
kubectl describe deployments hello-world


#Both replicasets remain, and that will become very useful shortly when we use a rollback :)
kubectl get replicaset


#The NewReplicaSet, check out labels, replicas, status and pod-template-hash
kubectl describe replicaset hello-world-b77646c68


#The OldReplicaSet, check out labels, replicas, status and pod-template-hash
kubectl describe replicaset hello-world-54575d5b77
