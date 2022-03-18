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
  name: trusted
handler: runsc

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
  runtimeClassName: trusted


Edit the questionablesoft-data.yml manifest file:

vi questionablesoft-data.yml
Add the runtimeClassName of runsc-sandbox:

spec:
  runtimeClassName: runsc-sandbox



To verify the Pods are running in a gVisor sandbox, check the Pods' dmesg output:

kubectl exec questionablesoft-api -n questionablesoft -- dmesg


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
### 2. create serviceaccounts
######################################################################## 

```

apiVersion: v1
kind: ServiceAccount
metadata:
  name: qwfrontend-sa
  namespace: qqa
automountServiceAccountToken: false



deleta a SA
-----------

kubectl delete serviceaccount/build-robot

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


        kubectl logs <CONTROL_PLANE_JOB_POD_NAME> > /home/cloud_user/kube-bench-control.log

        kubectl logs <NODE_JOB_POD_NAME> > /home/cloud_user/kube-bench-worker.log



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


ETCD file:
--------

sudo more /etc/kubernetes/manifests/etcd.yaml
```


```
# see all
kube-bench run --targets master

# or just see the one
kube-bench run --targets master --check 1.2.20

```


######################################################################## 
### 4. Networkpolicy That Denies All and ALLOWS only specific PORT
######################################################################## 

Create a Networkpolicy That Denies All Access to the Maintenance Pod

```

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: qadefaultdeny
  namespace: qaproduction
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

```

########################################################################  
###   POD SECURITY POLICIES
########################################################################

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


```

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: qapsp-restrict-sa
  namespace: qaproduction

```

```


apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: qadeny-access-bind
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: qarestrict-access-role
subjects:
- kind: ServiceAccount
  name: qapsp-restrict-sa


```

########################################################################  
###  6.RBAC
########################################################################


```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: qaweb-role-2
  namespace: qaistio-system
rules:
- apiGroups: [""]
  resources: ["pods"]
  # resources: ["namespaces"]
  verbs: ["watch"]
  # verbs: ["update"]
```

```


apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: qaweb-role-2-binding
  namespace: qaistio-system
subjects:
- kind: ServiceAccount
  name: qatest-sa-3
  namespace: qaistio-system
roleRef:
  kind: Role
  name: qaweb-role-2
  apiGroup: rbac.authorization.k8s.io

```

########################################################################  
###  Logging
########################################################################

Configure Audit Logging -- sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

```
- command:
  - kube-apiserver
  - --audit-policy-file=/etc/kubernetes/logpolicy/policy.yaml
  - --audit-log-path=/var/log/kubernetes/logs.txt
  - --audit-log-maxage=30
  - --audit-log-maxbackup=2

```

```
suod vim /etc/kubernetes/logpolicy/policy.yaml
---------------------------

apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["cronjobs"]
  - level: Request
    resources:
    - group: ""
      resources: ["persistentvolumes"]
    namespaces: ["frontweb"]
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets","configmaps"]
  - level: Metadata
```

########################################################################  
###  8.Secrets
########################################################################

```
echo $(kubectl get secret qatest-app -n qadb --template={{.data.username}} | base64 --decode )

```

```
kubectl create secret generic app1 --from-literal=USERNAME=app1login --from-literal=PASSWORD='S0methingS@Str0ng!'

apiVersion: v1
kind: Secret
metadata:
  name: app3
data:
  USERNAME: YXBwMmxvZ2lu
  PASSWORD: UzBtZXRoaW5nU0BTdHIwbmch
```

```
apiVersion: v1
kind: Secret
metadata:
  name: app2
stringData:
  USERNAME: app2login
  PASSWORD: S0methingS@Str0ng!s


```

```
apiVersion: v1
kind: Pod
metadata:
  name: qasecret-pod
  namespace: qadb
spec:
  containers:
  - name: qatest-secret-container
    image: httpd
    volumeMounts:
    - name: qatest-secret-volume
      mountPath: "/etc/secret"
      readOnly: true
  volumes:
  - name: qatest-secret-volume
    secret:
      secretName: mysecret

```

########################################################################  
###  Network POlicy
########################################################################
https://kubernetes.io/docs/concepts/services-networking/network-policies/

```
kubectl get pods --show-labels

```

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: qapod-restriction
  namespace: qadevelopment
spec:
  podSelector:
    matchLabels:
      app: qaproducts-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          role: auth
    - podSelector:
        matchLabels:
          environment: testing

```

########################################################################  
###  12.Image Scanning
########################################################################

sudo vi /etc/kubernetes/admission-control/admission-control.conf

```
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  # path: imagepolicy_backend.kubeconfig
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


```
GET PODS and CONTAINER IMAGE NAMES
--------------------------
kgp -n sunnydale -o jsonpath='{range .items[*]}{.metadata.name }{"\t"}{.spec.containers[*].image }{"\n"}{end}' --sort-by=.spec.containers[*].image

SCAN WITH TRIVY
--------------
trivy image -s HIGH,CRITICAL amazonlinux:1

```

########################################################################  
###  RBAC K8S API server
########################################################################



########################################################################  
###  AppArmor
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
###  Falco
########################################################################



FALCO rules file

```
- rule: spawned_process_in_monitor_container
  desc: A process was spawned in the Monitor container.
  condition: container.name = "monitor" and evt.type = execve
  output: "%evt.time,%user.uid,%proc.name"
  # priority: NOTICE
  priority: WARNING


RUN roles for 45 sec on the worker node
---------------

sudo falco -M 45 -r monitor_rules.yml > /home/cloud_user/falco_output.log

```
