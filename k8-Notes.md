### default configuration files location:

kubelet configuration = /var/lib/kubelet/config.yaml

## below path where secrets associated with serviceAccounts are mounted:
cd /var/run/secrets/kubernetes.io/serviceaccount/
 |
 |--> token, ca.crt, namespace  
 
AFTER LOGIN INTO POD, use the CURL to authenticate with K8s API server.
 
 CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
 curl --cacert $CA -X GET https://kubernetes/api

other way is TOKEN:

TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --cacert $CA -X GET https://kubernetes/api --header "Authorization: Bearer $TOKEN"
curl  -X GET https://kubernetes/api --header "Authorization: Bearer $TOKEN" --insecure





