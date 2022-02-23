#https://docs.microsoft.com/en-us/azure/aks/ssh#configure-virtual-machine-scale-set-based-aks-clusters-for-ssh-access

##########
###UPDATE:
###You no longer have to perform these many steps to get SSH access to a node in AKS, follow the directions in the link above.  
##########


#CLUSTER_RESOURCE_GROUP=$(az aks show --resource-group Kubernetes-Cloud --name CSCluster --query nodeResourceGroup -o tsv)
#SCALE_SET_NAME=$(az vmss list --resource-group $CLUSTER_RESOURCE_GROUP --query [0].name -o tsv)

#echo $CLUSTER_RESOURCE_GROUP
#echo $SCALE_SET_NAME

#az vmss extension set  \
#    --resource-group $CLUSTER_RESOURCE_GROUP \
#    --vmss-name $SCALE_SET_NAME \
#    --name VMAccessForLinux \
#    --publisher Microsoft.OSTCExtensions \
#    --version 1.4 \
#    --protected-settings "{\"username\":\"azureuser\", \"ssh_key\":\"$(cat ~/.ssh/id_rsa.pub)\"}"

#az vmss update-instances --instance-ids '*' \
#    --resource-group $CLUSTER_RESOURCE_GROUP \
#    --name $SCALE_SET_NAME

#kubectl run -it --rm aks-ssh --image=debian

#apt-get update && apt-get install openssh-client -y

#kubectl cp ~/.ssh/id_rsa $(kubectl get pod -l run=aks-ssh -o jsonpath='{.items[0].metadata.name}'):~/.ssh/id_rsa

#sudo apt-get install bridge-utils

#sudo brctl show