ssh aen@c1-master1
cd ~/content/course/03/demo


#1 - Create a certificate for a new user
#https://kubernetes.io/docs/concepts/cluster-administration/certificates/#cfssl
#Create a private key
openssl genrsa -out demouser.key 2048


#Generate a CSR
#CN (Common Name) is your username, O (Organization) is the Group
#If you get an error Can't load /home/USERNAME/.rnd into RNG - comment out RANDFILE from /etc/ssl/openssl.conf 
# see this link for more details https://github.com/openssl/openssl/issues/7754#issuecomment-541307674
openssl req -new -key demouser.key -out demouser.csr -subj "/CN=demouser"


#The certificate request we'll use in the CertificateSigningRequest
cat demouser.csr


#The CertificateSigningRequest needs to be base64 encoded
#And also have the header and trailer pulled out.
cat demouser.csr | base64 | tr -d "\n" > demouser.base64.csr


#UPDATE: If you're on 1.19+ use this CertificateSigningRequest
#Submit the CertificateSigningRequest to the API Server
#Key elements, name, request and usages (must be client auth)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: demouser
spec:
  groups:
  - system:authenticated  
  request: $(cat demouser.base64.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

#UPDATE: If you're on 1.18.x or below use this CertificateSigningRequest
#Submit the CertificateSigningRequest to the API Server
#Key elements, name, request and usages (must be client auth)
#cat <<EOF | kubectl apply -f -
#apiVersion: certificates.k8s.io/v1beta1
#kind: CertificateSigningRequest
#metadata:
#  name: demouser
#spec:
#  groups:
#  - system:authenticated  
#  request: $(cat demouser.base64.csr)
#  usages:
#  - client auth
#EOF


#Let's get the CSR to see it's current state. The CSR will delete after an hour
#This should currently be Pending, awaiting administrative approval
kubectl get certificatesigningrequests


#Approve the CSR
kubectl certificate approve demouser


#If we get the state now, you'll see Approved, Issued. 
#The CSR is updated with the certificate in .status.certificate
kubectl get certificatesigningrequests demouser 


#Retrieve the certificate from the CSR object, it's base64 encoded
kubectl get certificatesigningrequests demouser \
  -o jsonpath='{ .status.certificate }'  | base64 --decode


#Let's go ahead and save the certificate into a local file. 
#We're going to use this file to build a kubeconfig file to authenticate to the API Server with
kubectl get certificatesigningrequests demouser \
  -o jsonpath='{ .status.certificate }'  | base64 --decode > demouser.crt 


#Check the contents of the file
cat demouser.crt


#Read the certficate itself
#Key elements: Issuer is our CA, Validity one year, Subject CN=demousers
openssl x509 -in demouser.crt -text -noout | head -n 15


#Now that we have the certificate we can use that to build a kubeconfig file with to log into this cluster.
#We'll use demouser.key and demouser.crt
#More on that in an upcoming demo
ls demouser.*
