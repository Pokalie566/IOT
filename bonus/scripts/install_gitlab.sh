#!/bin/bash
# deploys gitlab in its own namespace on the k3d cluster built by p3

CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"

docker info >/dev/null 2>&1 || { echo "docker is not running" >&2; exit 1; }
kubectl config use-context k3d-iot || exit 1

kubectl apply -f "$CONFS/gitlab.yaml"

# omnibus runs migrations on first boot: a quarter of an hour is not unusual
echo "waiting for gitlab, this takes 10-15 minutes on first start"
kubectl -n gitlab rollout status deploy/gitlab --timeout=1200s || exit 1

echo
echo "gitlab   http://gitlab.gitlab.svc.cluster.local:8081"
echo "         (needs: echo '127.0.0.1 gitlab.gitlab.svc.cluster.local' | sudo tee -a /etc/hosts)"
echo "user     root"
echo "password $(kubectl -n gitlab exec deploy/gitlab -- \
	grep '^Password:' /etc/gitlab/initial_root_password | cut -d' ' -f2)"
echo
echo "clone url for argo cd (in-cluster dns):"
echo "  http://gitlab.gitlab.svc.cluster.local:8081/root/<project>.git"
