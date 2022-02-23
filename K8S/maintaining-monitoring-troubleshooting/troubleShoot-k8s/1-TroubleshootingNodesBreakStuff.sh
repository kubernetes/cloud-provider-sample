#To use this file to break stuff on your nodes, set the username variable to your username. 
#This account will need sudo rights on the nodes to break things.
#You'll need to enter your sudo password for this account on each node for each execution.
#Execute the commands here one line at a time rather than running the whole script at ones.
#You can set up passwordless sudo to make this easier otherwise 
USER=$1

# Worker Node - stopped kubelet
ssh $USER@c1-node1 -t 'sudo systemctl stop kubelet.service'
ssh $USER@c1-node1 -t 'sudo systemctl disable kubelet.service'


# Worker Node - inaccessible config.yaml
ssh $USER@c1-node2 -t 'sudo mv /var/lib/kubelet/config.yaml /var/lib/kubelet/config.yml'
ssh $USER@c1-node2 -t 'sudo systemctl restart kubelet.service'


# Worker Node - misconfigured systemd unit
ssh $USER@c1-node3 -t 'sudo sed -i ''s/config.yaml/config.yml/'' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf'
ssh $USER@c1-node3 -t 'sudo systemctl daemon-reload'
ssh $USER@c1-node3 -t 'sudo systemctl restart kubelet.service'
