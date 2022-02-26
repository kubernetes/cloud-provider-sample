
```
0)
--
alias k=kubectl                         # will already be pre-configured

export do="--dry-run=client -o yaml"    # k get pod x $do

export now="--force --grace-period 0"   # k delete pod x $now
```

```
1)
--
k config get-contexts # copy manually
k config get-contexts -o name > /opt/course/1/contexts
k config view -o yaml # overview
k config view -o jsonpath="{.contexts[*].name}"
k config view -o jsonpath="{.contexts[*].name}" | tr " " "\n" # new lines
k config view -o jsonpath="{.contexts[*].name}" | tr " " "\n" > /opt/course/1/contexts 

kubectl config current-context
cat ~/.kube/config | grep current | sed -e "s/current-context: //"

```

```
2 )
--
k get node # find master node

k describe node cluster1-master1 | grep Taint # get master node taints

k describe node cluster1-master1 | grep Labels -A 10 # get master node labels

k get node cluster1-master1 --show-labels # OR: get master node labels

k run pod1 --image=httpd:2.4.41-alpine $do > 2.yaml

```

```
3)
--

k -n project-c13 get pod | grep o3db
k -n project-c13 get deploy,ds,sts | grep o3db
k -n project-c13 get pod --show-labels | grep o3db
k -n project-c13 scale sts o3db --replicas 1 --record
k -n project-c13 describe sts o3db
```

