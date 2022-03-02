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
###       CIS Kubernetes Benchmark 
########################################################################  
```
Run kube-bench and Obtain a CIS Benchmark Report
Download the kube-bench Job manifest files:

        wget -O kube-bench-control-plane.yaml https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-master.yaml        
        wget -O kube-bench-node.yaml https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-node.yaml
Create the Jobs to run the benchmark files:

        kubectl create -f kube-bench-control-plane.yaml
        kubectl create -f kube-bench-node.yaml
Check the status of the Jobs:

        kubectl get pods
Save the benchmark results on the Jobs Pod logs, replacing the Pod name placeholder values with the actual Pod names:

        kubectl logs <CONTROL_PLANE_JOB_POD_NAME> > /home/cloud_user/kube-bench-control.log
        kubectl logs <NODE_JOB_POD_NAME> > /home/cloud_user/kube-bench-worker.log
Turn Off Profiling for the API Server, Controller Manager, and Scheduler
View the kube-bench test results for the control plane:

        cat /home/cloud_user/kube-bench-control.log
Scroll down to the failed test 1.2.20 and read the summary.

Scroll down to the Remediations master near the bottom and read under 1.2.20 for additional information on fixing the issue.
Scroll to 1.3.2 and 1.4.1 and read the information on fixing these issues.
Edit the Kubernetes API server manifest file using the provided lab password:

sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
Under containers:, add the following command beneath kube-apiserver to turn off profiling:

        spec:
          containers:
          - command:
            - kube-apiserver
            - --profiling=false

    ...
To save and exit the file, press Escape and enter :wq.

Repeat the process above to turn off profiling for the Kubernetes controller manager:

        spec:
          containers:
          - command:
            - kube-controller-manager
            - --profiling=false

    ...
Repeat the process again to turn off profiling for the Kubernetes scheduler:

        spec:
          containers:
          - command:
            - kube-scheduler
            - --profiling=false

    ...
Check the Pods:

        kubectl get pods -n kube-system
Set kubelet authn/authz to Use Webhook Mode
View the kube-bench test results for the worker node:

        cat /home/cloud_user/kube-bench-worker.log
Scroll down to the failed test 4.2.2 and read the summary.

Scroll down to the Remediations node near the bottom and read under 4.2.2 for additional information on fixing the issue.
Log in to the worker node server using the provided lab credentials:

ssh cloud_user@<PUBLIC_IP_ADDRESS>
Edit the kubelet configuration file using the provided lab password:

sudo vi /var/lib/kubelet/config.yaml
Set authorization.mode to Webhook:

authorization:
  mode: Webhook
Press Escape and enter :wq.

Restart kubelet:

        sudo systemctl restart kubelet
To verify the issues were fixed, return to the control plane server and delete the existing Jobs:

        kubectl delete job kube-bench-master
        kubectl delete job kube-bench-node
Re-run the Jobs:

        kubectl create -f kube-bench-control-plane.yaml
        kubectl create -f kube-bench-node.yaml
Check the Pods:

        kubectl get pods
Once the STATUS shows Completed, view the Pod logs, replacing the Pod name placeholder values with the actual Pod names:

        kubectl logs <CONTROL_PLANE_JOB_POD_NAME>
        kubectl logs <NODE_JOB_POD_NAME>
Check the results of the kube-bench tests. For the tests addressed, the results should now show [PASS]!
```


```
# see all
kube-bench run --targets master

# or just see the one
kube-bench run --targets master --check 1.2.20

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
  name: psp-no-privileged
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
  name: cr-use-psp-no-privileged
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs:     ['use']
  resourceNames:
  - psp-no-privileged

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
###   Move Kubernetes Pods to a Secured Runtime Sandbox (gVisor)
########################################################################

```
Install gVisor and Create a containerd Sandbox Configuration
Note: Perform the following steps on both the control plane and worker node.

Install gVisor:

curl -fsSL https://gvisor.dev/archive.key | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64,arm64] https://storage.googleapis.com/gvisor/releases release main"

sudo apt-get update && sudo apt-get install -y runsc
Edit the containerd configuration file to add configuration for runsc:

sudo vi /etc/containerd/config.toml
In the disabled_plugins section, add the restart plugin:

disabled_plugins = ["io.containerd.internal.v1.restart"]
Under [plugins], scroll down to [plugins."io.containerd.grpc.v1.cri".containerd.runtimes] and add the runsc runtime configuration:

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    ...
    
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
    runtime_type = "io.containerd.runsc.v1"
Scroll down to the [plugins."io.containerd.runtime.v1.linux"] block and set shim_debug to true:

[plugins."io.containerd.runtime.v1.linux"]

  ...

  shim_debug = true
To save and exit, type :wq and press Enter.

Restart containerd:

sudo systemctl restart containerd
Verify that containerd is still running:

sudo systemctl status containerd
Close out of the worker node. The remainder of the lab will be completed using only the control plane node.

Create a RuntimeClass for the Sandbox
On the control plane node, create a RuntimeClass:

```
```
vi runsc-sandbox.yml

apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: runsc-sandbox
handler: runsc
Type :wq and press Enter.
```
```
Create the sandbox in the cluster:

kubectl create -f runsc-sandbox.yml
Move All Pods in the questionablesoft Namespace to the New Runtime Sandbox
Retrieve the Pods in the questionablesoft namespace:

kubectl get pods -n questionablesoft
Delete the Pods:

kubectl delete pod questionablesoft-api -n questionablesoft --force

kubectl delete pod questionablesoft-data -n questionablesoft --force
Edit the questionablesoft-api.yml manifest file:

vi questionablesoft-api.yml
Under spec, add the runtimeClassName of runsc-sandbox:

spec:
  runtimeClassName: runsc-sandbox
Type :wq and press Enter.

Edit the questionablesoft-data.yml manifest file:

vi questionablesoft-data.yml
Add the runtimeClassName of runsc-sandbox:

spec:
  runtimeClassName: runsc-sandbox
Type :wq and press Enter.

Re-create the Pods:

kubectl create -f questionablesoft-api.yml

kubectl create -f questionablesoft-data.yml
To verify the Pods are running, retrieve them from the questionablesoft namespace:

kubectl get pods -n questionablesoft
To verify the Pods are running in a gVisor sandbox, check the Pods' dmesg output:

kubectl exec questionablesoft-api -n questionablesoft -- dmesg

kubectl exec questionablesoft-data -n questionablesoft -- dmesg
The output begins with Starting gVisor..., indicating the container process is running in a gVisor sandbox.

Compare this output to the non-sandboxed Pod securicorp-api in the default namespace:

kubectl exec securicorp-api -- dmesg
```
```
sample POD with a runtimeClassName
----------------------------------
apiVersion: v1
kind: Pod
metadata:
  name: questionablesoft-data
  namespace: questionablesoft
spec:
  runtimeClassName: runsc-sandbox
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'while true; do echo "Running..."; sleep 5; done']
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