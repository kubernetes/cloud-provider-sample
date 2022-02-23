ssh aen@c1-cp1
cd ~/content/course/04/demo/ 


#Run the code in 1-TroubleshootingNodesBreakstuff.sh...there's a readme inside this file. 
#This script will implement a breaking change on each worker node in the cluster
#You'll need to update the login username for this to work.
sh 1-TroubleshootingNodesBreakStuff.sh 'aen'


# Worker Node Troubleshooting Scenario 1
#It can take a minute for the node's status to change to NotReady...wait until they are.
#Except for the Control Plane Node, all of the Nodes' statuses are NotReady, let's check out why...
kubectl get nodes


#Remember the Control Plane Node still has a kubelet and runs pods...
#so this toubleshooting methodology can apply there.

#Let's start troubleshooting c1-node1's issues.
#ssh into c1-node1
ssh aen@c1-node1


#The kubelet runs as a systemd service/unit...so we can use those tools to troubleshoot why it's not working
#Let's start by checking the status. Add no-pager so it will wrap the text
#It's loaded, but it's inactive (dead)...so that means it's not running. 
#We want the service to be active (running)
#So the first thing to check is the service enabled?
sudo systemctl status kubelet.service


#If the service wasn't configured to start up by default (disabled) we can use enable to set it to.
sudo systemctl enable kubelet.service 


#That just enables the service to start up on boot, we could reboot now or we can start it manually
#So let's start it up and see what happens...ah, it's now actice (running) which means the kubelet is online.
#We also see in the journald snippet, that it's watching the apiserver. So good stuff there...
sudo systemctl start kubelet.service
sudo systemctl status kubelet.service 


#Log out of the node and onto c1-cp1
exit


#Back on c1-cp1, is c1-node1 reporting Ready?
kubectl get nodes


# Worker Node Troubleshooting Scenario 2
ssh aen@c1-node2


#Crashlooping kubelet...indicated by the code = exited and the status = 255
#But that didn't tell us WHY the kubelet is crashlooping, just that it is...let's dig deeper
sudo systemctl status kubelet.service --no-pager


#systemd based systems write logs to journald, let's ask it for the logs for the kubelet
#This tells us exactly what's wrong, the failed to load the Kubelet config file 
#which it thinks is at /var/lib/kubelet/config.yaml
sudo journalctl -u kubelet.service --no-pager



#Let's see what's in /var/lib/kubelet/...ah, look the kubelet wants config.yaml, but we have config.yml
sudo ls -la /var/lib/kubelet 


#And now fixup that config by renaming the file and and restarting the kubelet
#Another option here would have been to edit the systemd unit configuration for the kubelet in /etc/systemd/system/kubelet.service.d/10-kubeadm.conf.
#We're going to look at that in the next demo below.
sudo mv /var/lib/kubelet/config.yml  /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet.service 


#It should be Active(running)
sudo systemctl status kubelet.service 


#...lets log out and check the node status
exit


#On c1-cp1, c1-node2 should be Ready. 
kubectl get nodes


# Worker Node Troubleshooting Scenario 3 
ssh aen@c1-node3


#Crashlooping again...let's dig deeper and grab the logs
sudo systemctl status kubelet.service --no-pager


#Using journalctl we can pull the logs...this time it's looking for config.yml...
sudo journalctl -u kubelet.service --no-pager


#Is config.yml in /var/lib/kublet? No, it's config.yaml...but I don't want to rename this because 
#I wwant the filename so it matches all the configs on all my other nodes.
sudo ls -la /var/lib/kubelet


#Let's reconfigure where the kubelet looks for this config file
#Where is the kubelet config file specified?, check the systemd unit config for the kubelet
#Where does systemd think the kubelet's config.yaml is?
sudo systemctl status kubelet.service --no-pager
sudo more /etc/systemd/system/kubelet.service.d/10-kubeadm.conf


#Let's update the config args, inside here is the startup configuration for the kubelet
sudo vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf


#Let's restart the kubelet...
sudo systemctl restart kubelet 


#But since we edited the unit file, we neede to reload the unit files (configs)...then restart the service
sudo systemctl daemon-reload
sudo systemctl restart kubelet 


#Check the status...active and running?
sudo systemctl status kubelet.service


#Log out and back into c1-cp1
exit


#check our Nodes' statuses
kubectl get nodes
