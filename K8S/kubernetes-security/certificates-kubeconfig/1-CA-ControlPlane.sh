ssh aen@c1-master1
cd ~/content/course/03/demo


#1 - Investigating the PKI setup on the Control Plane Node
#The core pki directory, contains the certs and keys for all core functions in your cluster, 
#the self signed CA, server certificate and key for encryption by API Server, 
#etcd's cert setup, sa (serviceaccount) and more.
ls -l /etc/kubernetes/pki


#Read the ca.crt to view the certificates information, useful to determine the validity date of the certifcate
#You can use this command to read the information about any of the *.crt in this folder
#Be sure to check out the validity and the Subject CN
openssl x509 -in /etc/kubernetes/pki/ca.crt -text -noout | more




#2 - kubeconfig file location, for system components, controller manager, kubelet and scheduler.
ls /etc/kubernetes


#certificate-authority-data is a base64 encoded ca.cert
#You can also see the server for the API Server is https
#And there is also a client-certificate-data which is the client certificate used.
#And client-key-data is the private key for the client cert. these are used to authenticate the client to the api server
sudo more /etc/kubernetes/scheduler.conf
sudo kubectl config view --kubeconfig=/etc/kubernetes/scheduler.conf 


#The kube-proxy has it's kube-config as a configmap rather than a file on the file system.
kubectl get configmap -n kube-system kube-proxy -o yaml
