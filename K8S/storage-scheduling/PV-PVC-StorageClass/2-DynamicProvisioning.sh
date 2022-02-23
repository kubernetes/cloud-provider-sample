ssh aen@c1-cp1
cd ~/content/course/02/demos/

#Demo 0 - Azure Setup
#If you don't have your Azure Kubernetes Service Cluster available follow the script in CreateAKSCluster.sh


#Switch to our Azure cluster context
kubectl config use-context 'CSCluster'
kubectl get nodes 



#Demo 1 - StorageClasses and Dynamic Provisioning in the Azure
#Let's create a disk in Azure. Using a dynamic provisioner and storage class

#Check out our list of available storage classes, which one is default? Notice the Provisioner, Parameters and ReclaimPolicy.
kubectl get StorageClass
kubectl describe StorageClass default
kubectl describe StorageClass managed-premium


#let's create a Deployment of an nginx pod with a ReadWriteOnce disk, 
#we create a PVC and a Deployment that creates Pods that use that PVC
kubectl apply -f AzureDisk.yaml


#Check out the Access Mode, Reclaim Policy, Status, Claim and StorageClass
kubectl get PersistentVolume 


#Check out the Access Mode on the PersistentVolumeClaim, status is Bound and it's Volume is the PV dynamically provisioned
kubectl get PersistentVolumeClaim


#Let's see if our single pod was created (the Status can take a second to transition to Running)
kubectl get pods


#Clean up when we're finished and set our context back to our local cluster
kubectl delete deployment nginx-azdisk-deployment
kubectl delete PersistentVolumeClaim pvc-azure-managed




#Demo 2 - Defining a custom StorageClass in Azure
kubectl apply -f CustomStorageClass.yaml


#Get a list of the current StorageClasses kubectl get StorageClass.
kubectl get StorageClass

#A closer look at the SC, you can see the Reclaim Policy is Delete since we didn't set it in our StorageClass yaml
kubectl describe StorageClass managed-standard-ssd


#Let's use our new StorageClass
kubectl apply -f AzureDiskCustomStorageClass.yaml


#And take a closer look at our new Storage Class, Reclaim Policy Delete
kubectl get PersistentVolumeClaim
kubectl get PersistentVolume


#Clean up our demo resources
kubectl delete deployment nginx-azdisk-deployment-standard-ssd
kubectl delete PersistentVolumeClaim pvc-azure-standard-ssd
kubectl delete StorageClass managed-standard-ssd


#Switch back to our local cluster from Azure
kubectl config use-context kubernetes-admin@kubernetes
