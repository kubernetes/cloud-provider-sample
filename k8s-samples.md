########################################################################  
###  pod in a namespace on a particular node  ###############
######################################################################## 
```
apiVersion: v1
kind: Pod
metadata:
  name: fast-nginx
  namespace: dev
spec:
  nodeSelector:
    disk: fast
  containers:
  - name: nginx
    image: nginx
```

########################################################################  
### Create a Service to Expose the web-frontend Deployment's Pods Externally
######################################################################## 

```
apiVersion: v1
kind: Service
metadata:
  name: web-frontend-svc
  namespace: web
spec:
  type: NodePort
  selector:
    app: web-frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
```


########################################################################  
### Create an Ingress That Maps to the New Service
######################################################################## 
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-frontend-ingress
  namespace: web
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-frontend-svc
            port:
              number: 80
```
---
########################################################################  
### create serviceaccounts
######################################################################## 

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webautomation
  namespace: web
EOF
```
---
########################################################################  
### Create a ClusterRole That Provides Read Access to Pods
######################################################################## 

```
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
EOF
```

---
########################################################################  
###  Bind the ClusterRole to the Service Account to Only Read Pods in the web Namespace
######################################################################## 

```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rb-pod-reader
  namespace: web
subjects:
- kind: ServiceAccount
  name: webautomation
roleRef:
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---
########################################################################  
### create ClusterRoleBinding  ( grants that access cluster-wide.)
######################################################################## 

```
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pod-reader-ClusterRoleBinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: webautomation
EOF
```
---

########################################################################  
### storage class
######################################################################## 
```
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: localdisk
provisioner: kubernetes.io/no-provisioner
allowVolumeExpansion: true
EOF
```
---
########################################################################  
### Persistent Volume
######################################################################## 
```
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: host-storage-pv
spec:
  storageClassName: localdisk
  persistentVolumeReclaimPolicy: Recycle
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /etc/data
EOF
```
---

########################################################################  
### Persistent Volume Claim in AUTH namespace
######################################################################## 
```
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: host-storage-pvc
  namespace: auth
spec:
  storageClassName: localdisk
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
EOF
```
---
########################################################################  
### Create a Pod That Uses the PersistentVolume for Storage
######################################################################## 
```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pv-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'while true; do echo success > /output/output.log; sleep 5; done']
    volumeMounts:
    - name: pv-storage
      mountPath: /output
  volumes:
  - name: pv-storage
    persistentVolumeClaim:
      claimName: host-storage-pvc
EOF
```

########################################################################
### DEFAULT DENY of all incoming calls to a namespace
######################################################################## 
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: web-auth
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

---
```
kubectl get namespace web-auth --show-labels
kubectl get pods -n web-auth --show-labels
```

######################################################################## 
###    ALLOW only particular POD from a PARTICULAR namespace
######################################################################## 

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth-server-ingress
  namespace: web-auth
spec:
  podSelector:
    matchLabels:
      app: auth-server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          role: auth
      podSelector:
        matchLabels:
          app: auth-client
    ports:
    - protocol: TCP
      port: 80

```

######################################################################## 
###  create role and ROLE-BINDING with a service account 
######################################################################## 

```

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: auth
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  ## resources: ["services", "endpoints"] - when used for serives
  verbs: ["get", "list"]
```

```
kubectl create serviceaccount pod-monitor -n auth
```

```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-pod-monitor
  namespace: auth
subjects:
- kind: ServiceAccount
  name: pod-monitor
  namespace: auth
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io

```

######################################################################## 
###   CURL API POD SERVICES ACCESS
######################################################################## 

```
apiVersion: v1
kind: Pod
metadata:
  name: pod-watch
  namespace: auth
spec:
  serviceAccountName: pod-monitor
  containers:
  - name: busybox
    image: radial/busyboxplus:curl
    command: ['sh', '-c', 'TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token); while true; do if curl -s -o /dev/null -k -m 3 -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc.cluster.local/api/v1/namespaces/auth/services/; then echo "[SUCCESS] Successfully viewed Pods!"; else echo "[FAIL] Failed to view Pods!"; fi; sleep 5; done']

```

######################################################################## 
###  
######################################################################## 
