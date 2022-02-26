########################################################################  
### Creating Secrets
######################################################################## 

```
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


########################################################################  
### Different ways of passing ConfigMaps
######################################################################## 

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-configmaps-directory-qa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world-configmaps-directory-qa
  template:
    metadata:
      labels:
        app: hello-world-configmaps-directory-qa
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
        volumeMounts:
          - name: httpdconfig
            mountPath: "/etc/httpd"
            readOnly: true
      volumes:
        - name: httpdconfig
          configMap:
            name: httpdconfigprod1

```


```
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        envFrom:
          - configMapRef:
              name: appconfigprod
        ports:
        - containerPort: 8080

```

########################################################################  
### Pulling Image from PRIVATE REGISTRY
######################################################################## 


```
    spec:
      containers:
      - name: hello-world
        image: nocentino/hello-app:ps
        ports:
          - containerPort: 8080
      imagePullSecrets:
      - name: private-reg-cred


```

########################################################################  
###  Different Ways of Pulling Secrets
######################################################################## 

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-secrets-env-from
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world-secrets-env-from
  template:
    metadata:
      labels:
        app: hello-world-secrets-env-from
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        envFrom:
        - secretRef:
            name: app1
        ports:
        - containerPort: 8080

```

```
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        env:
        - name: app1username
          valueFrom:
            secretKeyRef:
              name: app1
              key: USERNAME 
        - name: app1password
          valueFrom:
            secretKeyRef:
              name: app1
              key: PASSWORD 
        ports:
        - containerPort: 8080

```

```
    spec:
      volumes:
        - name: appconfig
          secret:
            secretName: app1
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
        volumeMounts:
          - name: appconfig
            mountPath: "/etc/appconfig"

```

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
    env:
    - name: DATABASE_SERVERNAME
      value: "sql.example.local"
    - name: BACKEND_SERVERNAME
      value: "be.example.local"
    ports:
    - containerPort: 8080

```

########################################################################  
###   DEPLOYMENT with ROLLING UPDATE
######################################################################## 

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 20
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 10%
      maxSurge: 2
  revisionHistoryLimit: 20
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:2.0
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /index.html
            port: 8081
          initialDelaySeconds: 10
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world
spec:
  selector:
    app: hello-world
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080

```

########################################################################  
###  POD and DEPLOYMENT with LABELS
######################################################################## 


```
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod-1
  labels: 
    app: MyWebApp
    deployment: v1
    tier: prod
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
  dnsPolicy: "None"
  dnsConfig:
    nameservers:
      - 9.9.9.9


```

--

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
  labels:
    app: hello-world
  namespace: playground1
spec:
  replicas: 4
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080

```

########################################################################  
### JObs & CronJob and ParallelJObs
######################################################################## 


```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-world-cron
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: ubuntu
            image: ubuntu
            command:
            - "/bin/bash"
            - "-c"
            - "/bin/echo Hello from Pod $(hostname) at $(date)"
          restartPolicy: Never


----


apiVersion: batch/v1
kind: Job
metadata:
  name: hello-world-job-fail
spec:
  backoffLimit: 2
  template:
    spec:
      containers:
      - name: ubuntu
        image: ubuntu
        command:
         - "/bin/bash"
         - "-c"
         - "/bin/ech Hello from Pod $(hostname) at $(date)"
      restartPolicy: Never

---

apiVersion: batch/v1
kind: Job
metadata:
  name: hello-world-job-parallel
spec:
  completions: 50
  parallelism: 10
  template:
    spec:
      containers:
      - name: ubuntu
        image: ubuntu
        command:
         - "/bin/bash"
         - "-c"
         - "/bin/echo Hello from Pod $(hostname) at $(date)"
      restartPolicy: Never

```

########################################################################  
### StatefulSet
######################################################################## 


```
apiVersion: v1
kind: Service
metadata:
 name: mongo
 labels:
    name: mongo
spec:
 ports:
 - port: 27017
 clusterIP: None
 selector:
  role: mongo
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
 name: mongo
spec:
 selector:
  matchLabels:
    role: mongo
 serviceName: "mongo"
 replicas: 3
 template:
  metadata:
   labels:
    role: mongo
    environment: test
  spec:
    terminationGracePeriodSeconds: 10
    containers:
    - name: mongo
      image: mongo
      command:
        - mongod
        - "--replSet"
        - rs0
        - "--smallfiles"
        - "--noprealloc"
      ports:
        - containerPort: 27017
      volumeMounts:
        - name: mongo-persistent-storage
          mountPath: /data/db
    - name: mongo-sidecar
      image: cvallance/mongo-k8s-sidecar
      env:
        - name: MONGO_SIDECAR_POD_LABELS
          value: "role=mongo,environment=test"
 volumeClaimTemplates:
  - metadata:
      name: mongo-persistent-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Gi

```


########################################################################  
### ReplicaSet with matchExpressions
######################################################################## 


```
apiVersion: apps/v1
kind: ReplicaSet
metadata:
    name: hello-world-me
spec:
  replicas: 3
  selector:
    matchExpressions:
      - key: app
        operator: In
        values:
          - hello-world-pod-me
  template:
    metadata:
      labels:
        app: hello-world-pod-me
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080

```

########################################################################  
### DaemonSet with NodeSelectors
######################################################################## 

```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: hello-world-ds
spec:
  selector:
    matchLabels:
      app: hello-world-app
  template:
    metadata:
      labels:
        app: hello-world-app
    spec:
      nodeSelector:
        node: hello-world-ns
      containers:
        - name: hello-world
          image: gcr.io/google-samples/hello-app:1.0

```

########################################################################  
### INIT Containers
######################################################################## 

```
apiVersion: v1
kind: Pod
metadata:
  name: init-containers
spec:
  initContainers:
  - name: init-service
    image: ubuntu
    command: ['sh', '-c', "echo waiting for service; sleep 2"]
  - name: init-database
    image: ubuntu
    command: ['sh', '-c', "echo waiting for database; sleep 2"]
  containers:
  - name: app-container
    image: nginx

```

########################################################################  
### POD RESTART POLICY
######################################################################## 


```
apiVersion: v1
kind: Pod
metadata:
  name: hello-world-onfailure-pod
spec:
  containers:
  - name: hello-world
    image: gcr.io/google-samples/hello-app:1.0
  restartPolicy: OnFailure #Never
    ports:
    - containerPort: 80

```

########################################################################  
### StartUpProbe / LivenessProbe / ReadinessProbe
######################################################################## 



```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
        startupProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 1
        livenessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
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

---

apiVersion: v1
kind: Service
metadata:
  name: hello-world-api
spec:
  type: ExternalName
  externalName: hello-world.api.example.com
  
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

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-path
spec:
  ingressClassName: nginx
  rules:
    - host: path.example.com
      http:
        paths:
        - path: /red
          pathType: Prefix
          backend:
            service:
              name: hello-world-service-red
              port: 
                number: 4242
        - path: /blue
          pathType: Prefix
          backend:
            service:
              name: hello-world-service-blue
              port: 
                number: 4343
  defaultBackend:
    service:
        name: hello-world-service-single
        port: 
            number: 80
```

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
spec:
  ingressClassName: nginx
  tls:
  - hosts:
      - tls.example.com
    secretName: tls-secret
  rules:
  - host: tls.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world-service-single
            port:
              number: 80

```

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
### Affinity, Anti-Affinity and Tolerations
######################################################################## 

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world-web
  template:
    metadata:
      labels:
        app: hello-world-web
    spec:
      containers:
      - name: hello-world-web
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world-cache
  template:
    metadata:
      labels:
        app: hello-world-cache
    spec:
      containers:
      - name: hello-world-cache
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - hello-world-web
            topologyKey: "kubernetes.io/hostname"

```


```
Anti Affinity
-------------

apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world-web
  template:
    metadata:
      labels:
        app: hello-world-web
    spec:
      containers:
      - name: hello-world-web
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - hello-world-web
              topologyKey: "kubernetes.io/hostname"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world-cache
  template:
    metadata:
      labels:
        app: hello-world-cache
    spec:
      containers:
      - name: hello-world-cache
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - hello-world-web
            topologyKey: "kubernetes.io/hostname"

```


```
Tolerations
-----------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-tolerations
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-world-tolerations
  template:
    metadata:
      labels:
        app: hello-world-tolerations
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
      tolerations:
      - key: "key"
        operator: "Equal"
        value: "MyTaint"
        effect: "NoSchedule"


```
########################################################################
### PV, PVC using NFS.
######################################################################## 


```

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-nfs-deployment
spec:  
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      volumes:
      - name: webcontent
        persistentVolumeClaim:
          claimName: pvc-nfs-data
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: webcontent
          mountPath: "/usr/share/nginx/html/web-app"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-nfs-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80

---

apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs-data
spec:
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 10Gi
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: 172.16.94.5
    path: "/export/volumes/pod"

---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfs-data
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi

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
###  Networkpolicy That Denies All and ALLOWS only specific PORT
######################################################################## 

Create a Networkpolicy That Denies All Access to the Maintenance Pod

```
kubectl describe pod maintenance -n foo  (to check the POD labels)


apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-maintenance
  namespace: foo
spec:
  podSelector:
    matchLabels:
      app: maintenance
  policyTypes:
  - Ingress
  - Egress

```
kubectl label namespace users-backend app=users-backend

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-users-backend-80
  namespace: users-backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app: users-backend
    ports:
    - protocol: TCP
      port: 80
```
 

######################################################################## 
###  Create a Pod Which Uses a Sidecar to Expose the Main Container's Log File to stdout
######################################################################## 

```
apiVersion```: v1
kind: Pod
metadata:
  name: logging-sidecar
  namespace: baz
spec:
  containers:
  - name: busybox1
    image: busybox
    command: ['sh', '-c', 'while true; do echo Logging data > /output/output.log; sleep 5; done']
    volumeMounts:
    - name: sharedvol
      mountPath: /output
  - name: sidecar
    image: busybox
    command: ['sh', '-c', 'tail -f /input/output.log']
    volumeMounts:
    - name: sharedvol
      mountPath: /input
  volumes:
  - name: sharedvol
    emptyDir: {}


```