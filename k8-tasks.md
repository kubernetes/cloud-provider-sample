########################################################################  
###   UPGRADE CLUSTER   
######################################################################## 

#### Upgrade All Kubernetes Components on the Control Plane Node
#### Switch to the appropriate context with kubectl:
kubectl config use-context acgk8s

Upgrade kubeadm:
```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubeadm=1.22.2-00
```
Drain the control plane node:

kubectl drain acgk8s-control --ignore-daemonsets

Plan the upgrade:

sudo kubeadm upgrade plan v1.22.2

Apply the upgrade:

sudo kubeadm upgrade apply v1.22.2

Upgrade kubelet and kubectl:
```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubelet=1.22.2-00 kubectl=1.22.2-00
```
Reload:

sudo systemctl daemon-reload

Restart kubelet:

sudo systemctl restart kubelet

Uncordon the control plane node:

kubectl uncordon acgk8s-control

Upgrade All Kubernetes Components on the Worker Node

Drain the worker1 node:

kubectl drain acgk8s-worker1 --ignore-daemonsets --force

SSH into the node:

ssh acgk8s-worker1

Install a new version of kubeadm:
```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubeadm=1.22.2-00
```
Upgrade the node:

sudo kubeadm upgrade node

Upgrade kubelet and kubectl:
```
sudo apt-get update && \
sudo apt-get install -y --allow-change-held-packages kubelet=1.22.2-00 kubectl=1.22.2-00
```
Reload:

sudo systemctl daemon-reload

Restart kubelet:

sudo systemctl restart kubelet

Type exit to exit the node.

Uncordon the node:

kubectl uncordon acgk8s-worker1

Repeat the process above for acgk8s-worker2 to upgrade the other worker node.

########################################################################  
###  Back UP ETCD data & Restore    ###################
######################################################################## 

```
Back Up the etcd Data
From the terminal, log in to the etcd server:

ssh etcd1
Back up the etcd data:


ETCDCTL_API=3 etcdctl snapshot save /home/cloud_user/etcd_backup.db \
--endpoints=https://etcd1:2379 \
--cacert=/home/cloud_user/etcd-certs/etcd-ca.pem \
--cert=/home/cloud_user/etcd-certs/etcd-server.crt \
--key=/home/cloud_user/etcd-certs/etcd-server.key

Restore the etcd Data from the Backup
Stop etcd:

sudo systemctl stop etcd
Delete the existing etcd data:

sudo rm -rf /var/lib/etcd
Restore etcd data from a backup:

sudo ETCDCTL_API=3 etcdctl snapshot restore /home/cloud_user/etcd_backup.db \
--initial-cluster etcd-restore=https://etcd1:2380 \
--initial-advertise-peer-urls https://etcd1:2380 \
--name etcd-restore \
--data-dir /var/lib/etcd
Set database ownership:

sudo chown -R etcd:etcd /var/lib/etcd
Start etcd:

sudo systemctl start etcd
Verify the system is working:

ETCDCTL_API=3 etcdctl get cluster.name \
--endpoints=https://etcd1:2379 \
--cacert=/home/cloud_user/etcd-certs/etcd-ca.pem \
--cert=/home/cloud_user/etcd-certs/etcd-server.crt \
--key=/home/cloud_user/etcd-certs/etcd-server.key
```

########################################################################  
###  Drain Worker Node 1 ##############
### Create a Pod That Will Only Be Scheduled on Nodes with a Specific Label
######################################################################## 

```
Attempt to drain the worker1 node:
kubectl drain acgk8s-worker1

Does the node drain successfully?
Override the errors and drain the node:

kubectl drain acgk8s-worker1 --delete-local-data --ignore-daemonsets --force
                        or
kubectl drain acgk8s-worker1 --ignore-daemonsets --delete-emptydir-data --force

kubectl label nodes acgk8s-worker2 disk=fast

kubectl get pod fast-nginx -n dev -o wide
```


########################################################################  
###       Checing the BINARIES and CHECKSUM 
########################################################################  
VERSION=$(cat version.txt)

```
curl -LO "https://dl.k8s.io/$VERSION/bin/linux/amd64/kubectl.sha256"
curl -LO "https://dl.k8s.io/$VERSION/bin/linux/amd64/kubelet.sha256"
curl -LO "https://dl.k8s.io/$VERSION/bin/linux/amd64/kube-apiserver.sha256"

echo "$(<kubectl.sha256) kubectl" | sha256sum --check
echo "$(<kubelet.sha256) kubelet" | sha256sum --check
echo "$(<kube-apiserver.sha256) kube-apiserver" | sha256sum --check
```

########################################################################  
###   Protect a Kubernetes Cluster with AppArmor    
########################################################################

sample AppArmor policy file to deny writes onto DISK.
```
#include <tunables/global>
profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  # Deny all file writes.
  deny /** w,
}
```

```
apiVersion: v1
kind: Pod
metadata:
  name: password-db
  namespace: auth
  annotations:
    container.apparmor.security.beta.kubernetes.io/password-db: localhost/k8s-deny-write
spec:
  containers:
  - name: password-db
    image: radial/busyboxplus:curl
    command: ['sh', '-c', 'while true; do if echo "The password is hunter2" > password.txt; then echo "Password hunter2 logged."; else echo "Password log attempt blocked."; fi; sleep 5; done']
```
using APPArmor.

```
sudo apparmor_parser apparmor-k8s-deny-write

sudo cp apparmor-k8s-deny-write /etc/apparmor.d

sudo chown root:root /etc/apparmor.d/apparmor-k8s-deny-write
```
kubectl exec password-db -n auth -- cat password.txt



########################################################################  
###   POD SECURITY POLICIES
########################################################################

[](images/psp.png)
<img src="images/psp.png" width="400" >

sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

add this  --enable-admission-plugins=NodeRestriction,PodSecurityPolicy


```
vim psp-no-privileged.yml

apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: qarestrict-policy
spec:
  privileged: false
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - persistentVolumeClaim
  - secret
  - projected

```
Create an RBAC Setup to Apply the PodSecurityPolicy in the auth Namespace

```
vim cr-use-psp-no-privileged.yml

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: qarestrict-access-role
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs:     ['use']
  resourceNames:
  - qarestrict-policy

--------

vim rb-auth-sa-psp.yml


apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rb-auth-sa-psp
  namespace: auth
roleRef:
  kind: ClusterRole
  name: cr-use-psp-no-privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: auth-sa
  namespace: auth

------
PRIVILEGED POD


apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: auth
spec:
  serviceAccount: auth-sa
  containers:
  - name: background-monitor
    image: radial/busyboxplus:curl
    command: ['sh', '-c', 'while true; do echo "Running..."; sleep 5; done']
    securityContext:
      privileged: true


-----
NON PRIVILEGED POD

apiVersion: v1
kind: Pod
metadata:
  name: non-privileged-pod
  namespace: auth
spec:
  serviceAccount: auth-sa
  containers:
  - name: background-monitor
    image: radial/busyboxplus:curl
    command: ['sh', '-c', 'while true; do echo "Running..."; sleep 5; done']

```

########################################################################  
###   Manage Sensitive Config Data with Kubernetes Secrets
########################################################################

```
kubectl get secret db-pass -o yaml -n users

echo aHVudGVyMgo= | base64 --decode > /home/cloud_user/dbpass.txt

echo TrustNo1 | base64

kubectl edit secret db-pass -n users

```


########################################################################  
###   Automate Kubernetes Image Vulnerability Scanning
########################################################################

sudo vi /etc/kubernetes/admission-control/admission-control.conf

```
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/admission-control/imagepolicy_backend.kubeconfig
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
```

sudo vi /etc/kubernetes/admission-control/imagepolicy_backend.kubeconfig

```
apiVersion: v1
kind: Config
clusters:
- name: trivy-k8s-webhook
  cluster:
    certificate-authority: /etc/kubernetes/admission-control/imagepolicywebhook-ca.crt
    server: ""
contexts:
- name: trivy-k8s-webhook
  context:
    cluster: trivy-k8s-webhook
    user: api-server
current-context: trivy-k8s-webhook
preferences: {}
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/admission-control/api-server-client.crt
    client-key: /etc/kubernetes/admission-control/api-server-client.key

```

Enable Any Necessary Admission Control Plugins

```
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

--enable-admission-plugins=NodeRestriction,ImagePolicyWebhook

```


########################################################################  
###   Threat Detection in Kubernetes with Falco
########################################################################

Create a Falco Rules File Configured To Scan the Container
```
- rule: spawned_process_in_nginx_container
  desc: A process was spawned in the Nginx container.
  condition: container.name = "nginx" and evt.type = execve
  output: "%evt.time,%proc.name,%user.uid,%container.id,%container.name,%container.image"
  priority: WARNING
```

Run Falco to Obtain a Report of the Activity and Save It to a File

```
sudo falco -r nginx-rules.yml -M 45 > /home/cloud_user/falco-report.log
```

########################################################################  
###   Configure Audit Logging in Kubernetes
########################################################################

WRIET a AUDIT POLICY -- sudo vi /etc/kubernetes/audit-policy.yaml
```
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log request and response bodies for all changes to Namespaces.
- level: RequestResponse
  resources:
  - group: ""
    resources: ["namespaces"]

# Log request bodies (but not response bodies) for changes to Pods and Services in the web Namespace.
- level: Request
  resources:
  - group: ""
    resources: ["pods", "services"]
  namespaces: ["web"]

# Log metadata for all changes to Secrets.
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]

# Create a catchall rule to log metadata for all other requests.
- level: Metadata
```
Configure Audit Logging -- sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

```
- command:
  - kube-apiserver
  - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
  - --audit-log-path=/var/log/kubernetes/k8s-audit.log
  - --audit-log-maxage=60
  - --audit-log-maxbackup=1

```

### if mentioned that files on the host and container.

```
# add new Volumes
volumes:
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit-policy/policy.yaml
      type: File
  - name: audit-logs
    hostPath:
      path: /etc/kubernetes/audit-logs
      type: DirectoryOrCreate


# add new VolumeMounts
volumeMounts:
  - mountPath: /etc/kubernetes/audit-policy/policy.yaml
    name: audit-policy
    readOnly: true
  - mountPath: /etc/kubernetes/audit-logs
    name: audit-logs
    readOnly: false

```

########################################################################  
###   Image Scanning - Admission Control
########################################################################

```
/etc/kubernetes/admission-control/admission-control.conf

apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  path: imagepolicy.conf

```

```
/etc/kubernetes/admission-control/imagepolicy.conf

{
   "imagePolicy": {
      "kubeConfigFile": "/etc/kubernetes/admission-control/imagepolicy_backend.kubeconfig",
      "allowTTL": 50,
      "denyTTL": 50,
      "retryBackoff": 500,
      "defaultAllow": true
   }
}
```

```
/etc/kubernetes/admission-control/imagepolicy_backend.kubeconfig


apiVersion: v1
kind: Config
clusters:
- name: trivy-k8s-webhook
  cluster:
    certificate-authority: /etc/kubernetes/admission-control/imagepolicywebhook-ca.crt
    server: ""
contexts:
- name: trivy-k8s-webhook
  context:
    cluster: trivy-k8s-webhook
    user: api-server
current-context: trivy-k8s-webhook
preferences: {}
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/admission-control/api-server-client.crt
    client-key: /etc/kubernetes/admission-control/api-server-client.key
```

########################################################################  
###  TRIVY  Image Scanning - FOR THE exiting PODs
########################################################################


```
GET PODS and CONTAINER IMAGE NAMES
--------------------------
kgp -n sunnydale -o jsonpath='{range .items[*]}{.metadata.name }{"\t"}{.spec.containers[*].image }{"\n"}{end}' --sort-by=.spec.containers[*].image

SCAN WITH TRIVY
--------------
trivy image -s HIGH,CRITICAL amazonlinux:1

```

########################################################################  
###  AppArmor PROFILE.
########################################################################

```

#include <tunables/global>
profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  # Deny all file writes.
  deny /** w,
}

ENFORCE the file in the WORKER NODE
-----
sudo apparmor_parser /home/cloud_user/k8s-deny-write


Applying it to a container
-------

apiVersion: v1
kind: Pod
metadata:
  name: chewbacca
  namespace: kashyyyk
  annotations:
    container.apparmor.security.beta.kubernetes.io/busybox: localhost/k8s-deny-write
spec:
  containers:
  - name: busybox
    image: busybox:1.33.1
    command: ['sh', '-c', 'while true; do echo hunter2 > password.txt; sleep 5; done']


```


####### #################################################################  
###  Behaviour Analysis - FALCO profile
########################################################################

FALCO rules file

```
- rule: spawned_process_in_monitor_container
  desc: A process was spawned in the Monitor container.
  condition: container.name = "monitor" and evt.type = execve
  output: "%evt.time,%container.id,%container.image,%user.uid,%proc.name"
  priority: NOTICE



RUN roles for 45 sec on the worker node
---------------

sudo falco -M 45 -r monitor_rules.yml > /home/cloud_user/falco_output.log

```

####### #################################################################  
###  Cluster's Audit Policy
########################################################################

```
suod vim /etc/kubernetes/audit-policy.yaml
---------------------------

apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["configmaps"]
  - level: Request
    resources:
    - group: ""
      resources: ["services", "pods"]
    namespaces: ["web"]
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets"]
  - level: Metadata
```

```
Configure audit logging for the cluster.
--------------
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml 

- command:
  - kube-apiserver
  - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
  - --audit-log-path=/var/log/kubernetes/audit.log
  - --audit-log-maxage=10
  - --audit-log-maxbackup=1

```

######################################################################  
###  Create a Secret and Encode & Decode Data
######################################################################

echo MTIzNDUK | base64 --decode

```
apiVersion: v1
kind: Secret
metadata:
  name: moe
  namespace: larry
type: Opaque
data:
  username: ZGJ1c2VyCg==
  password: QTgzTWFlS296Cg==

```

Mount it to a POD

```
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
  namespace: larry
spec:
  containers:
  - name: busybox
    image: busybox:1.33.1
    command: ['sh', '-c', 'cat /etc/credentials/username; cat /etc/credentials/password; while true; do sleep 5; done']
    volumeMounts:
    - name: credentails
      mountPath: /etc/credentials
      readOnly: true
  volumes:
  - names: credentails
    secret:
      secretName: moe

```

######################################################################  
###  Create a RUNTIME CLASS and gVISOR Sandbox 
######################################################################

```
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: sandbox
handler: runsc
```

use this class

```

 spec:
      runtimeClassName: sandbox
      containers:
```

check if it running in gVISOR with dmesg

```
k exec -n sunnydale buffy-86f6477848-kwkb8 -- dmesg
```

######################################################################  
### Create a PodSecurityPolicy to Prevent Privileged Containers
######################################################################

```
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: nopriv-psp
spec:
  privileged: false
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny


```

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: use-nopriv-psp
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs:     ['use']
  resourceNames:
  - nopriv-psp
```

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: hoth-sa-use-nopriv-psp
roleRef:
  kind: ClusterRole
  name: use-nopriv-psp
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: hoth-sa
  namespace: hoth

```