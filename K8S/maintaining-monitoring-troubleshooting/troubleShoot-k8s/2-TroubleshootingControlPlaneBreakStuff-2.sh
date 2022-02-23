#Break the scheduler control plane pod
sudo cp /etc/kubernetes/manifests/kube-scheduler.yaml ~/kube-scheduler.yaml.ORIG
sudo sed -i 's/image: k8s.gcr.io\/kube-scheduler:/image: k8s.gcr.io\/kube-cheduler:/' /etc/kubernetes/manifests/kube-scheduler.yaml
