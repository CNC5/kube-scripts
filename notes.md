## metrics API manifest HA:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/high-availability-1.21+.yaml

## NGINX ingress
git clone https://github.com/nginxinc/kubernetes-ingress.git --branch v3.7.2

cd kubernetes-ingress
kubectl apply -f deployments/common/ns-and-sa.yaml
kubectl apply -f deployments/rbac/rbac.yaml
kubectl apply -f deployments/common/nginx-config.yaml

# edit before applying
nano deployments/common/ingress-class.yaml
kubectl apply -f deployments/common/ingress-class.yaml

kubectl apply -f config/crd/bases/k8s.nginx.org_virtualservers.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_virtualserverroutes.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_transportservers.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_policies.yaml
kubectl apply -f config/crd/bases/k8s.nginx.org_globalconfigurations.yaml

kubectl apply -f deployments/deployment/nginx-ingress.yaml
kubectl apply -f deployments/service/nodeport.yaml

## Fetch etcd status
etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
    --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
    --endpoints=<endpoint-ip>:2379 member list
