#!/bin/bash
# creates the k3d cluster, installs argo cd, points it at the app repo

CLUSTER=iot
CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"

docker info >/dev/null 2>&1 || { echo "docker is not running" >&2; exit 1; }

k3d cluster list "$CLUSTER" >/dev/null 2>&1 || k3d cluster create "$CLUSTER" \
	--port "8080:30080@loadbalancer" \
	--port "8888:30888@loadbalancer" \
	--port "8081:30081@loadbalancer"

kubectl config use-context "k3d-$CLUSTER" || exit 1

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f \
	https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd patch configmap argocd-cmd-params-cm \
	--type merge -p '{"data":{"server.insecure":"true"}}'
kubectl -n argocd patch svc argocd-server \
	-p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30080}]}}'

kubectl -n argocd rollout restart deploy/argocd-server
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

kubectl apply -f "$CONFS/application.yaml"

cat <<EOF

argo cd  http://localhost:8080
user     admin
password $(kubectl -n argocd get secret argocd-initial-admin-secret \
	-o jsonpath='{.data.password}' | base64 -d)
app      http://localhost:8888
EOF
