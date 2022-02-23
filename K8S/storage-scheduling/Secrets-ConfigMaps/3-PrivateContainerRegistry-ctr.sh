#Log into the Control Plane Node to drive these demos.
ssh aen@c1-cp1
cd ~/content/course/03/demos


#Demo 1 - Pulling a Container from a Private Container Registry


#To create a private repository in our registry, follow the directions here
#https://docs.docker.com/docker-hub/repos/#private-repositories


#Let's pull down a hello-world image from gcr
sudo ctr images pull gcr.io/google-samples/hello-app:1.0


#Let's get a listing of images from ctr to confim our image is downloaded
sudo ctr images list


#Tagging our image in the format your registry, image and tag
#You'll be using your own repository, so update that information here. 
#  source_ref: gcr.io/google-samples/hello-app:1.0    #this is the image pulled from gcr
#  target_ref: docker.io/nocentino/hello-app:ps       #this is the image you want to push into your private repository
sudo ctr images tag gcr.io/google-samples/hello-app:1.0 docker.io/nocentino/hello-app:ps


#Now push that locally tagged image into our private registry at docker hub
#You'll be using your own repository, so update that information here and specify your $USERNAME
#You will be prompted for the password to your repository
sudo ctr images push docker.io/nocentino/hello-app:ps --user $USERNAME


#Create our secret that we'll use for our image pull...
#Update the paramters to match the information for your repository including the servername, username, password and email.
kubectl create secret docker-registry private-reg-cred \
    --docker-server=https://index.docker.io/v2/ \
    --docker-username=$USERNAME \
    --docker-password=$PASSWORD \
    --docker-email=$EMAIL


#Ensure the image doesn't exist on any of our nodes...or else we can get a false positive since our image would be cached on the node
#Caution, this will delete *ANY* image that begins with hello-app
ssh aen@c1-node1 'sudo ctr --namespace k8s.io image ls "name~=hello-app" -q | sudo xargs ctr --namespace k8s.io image rm'
ssh aen@c1-node2 'sudo ctr --namespace k8s.io image ls "name~=hello-app" -q | sudo xargs ctr --namespace k8s.io image rm'
ssh aen@c1-node3 'sudo ctr --namespace k8s.io image ls "name~=hello-app" -q | sudo xargs ctr --namespace k8s.io image rm'


#Create a deployment using imagePullSecret in the Pod Spec.
kubectl apply -f deployment-private-registry.yaml


#Check out Containers and events section to ensure the container was actually pulled.
#This is why I made sure they were deleted from each Node above. 
kubectl describe pods hello-world


#Clean up after our demo, remove the images from c1-cp1.
kubectl delete -f deployment-private-registry.yaml
kubectl delete secret private-reg-cred
sudo ctr images remove docker.io/nocentino/hello-app:ps
sudo ctr images remove gcr.io/google-samples/hello-app:1.0
