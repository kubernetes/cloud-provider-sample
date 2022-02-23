ssh aen@c1-master1
cd ~/content/course/02/demos


#1 - Changing authorization for a service account
#We left off with where serviceaccount didn't have access to the API Server to access Pods
kubectl auth can-i list pods --as=system:serviceaccount:default:mysvcaccount1


#But we can create an RBAC Role and bind that to our service account
#We define who, can perform what verbs on what resources
kubectl create role demorole --verb=get,list --resource=pods
kubectl create rolebinding demorolebinding --role=demorole --serviceaccount=default:mysvcaccount1 


#Then the service account can access the API with the 
#https://kubernetes.io/docs/reference/access-authn-authz/rbac/#service-account-permissions
kubectl auth can-i list pods --as=system:serviceaccount:default:mysvcaccount1
kubectl get pods -v 6 --as=system:serviceaccount:default:mysvcaccount1


#Go back inside the pod again...
kubectl get pods 
PODNAME=$(kubectl get pods -l app=nginx -o jsonpath='{ .items[*].metadata.name }')
kubectl exec $PODNAME -it -- /bin/bash


#Load the token and cacert into variables for reuse
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt


#Now I can view objects...this isn't just for curl but for any application. 
#Apps commonly use libraries to programmaticly interact with the api server for cluster state information 
curl --cacert $CACERT --header "Authorization: Bearer $TOKEN" -X GET https://kubernetes.default.svc/api/v1/namespaces/default/pods
exit 


#Clean up from this demo
kubectl delete deployment nginx
kubectl delete serviceaccount mysvcaccount1
kubectl delete role demorole 
kubectl delete rolebinding demorolebinding 
