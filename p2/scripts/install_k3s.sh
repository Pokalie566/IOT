#!/bin/bash
# k3s server + deploy the 3 apps and the ingress

SERVER_IP="$1"

IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP/" '$4 ~ ip {print $2; exit}')
if [ -z "$IFACE" ]; then
	echo "no interface holds $SERVER_IP" >&2
	ip -o -4 addr show >&2
	exit 1
fi
echo "private iface: $IFACE"

if systemctl cat chrony-wait.service >/dev/null 2>&1; then
	systemctl start chrony-wait
elif systemctl cat systemd-time-wait-sync.service >/dev/null 2>&1; then
	systemctl start systemd-timesyncd
	systemctl start systemd-time-wait-sync
else
	echo "no clock sync service, refusing to install k3s" >&2
	exit 1
fi

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
	--node-ip=$SERVER_IP \
	--advertise-address=$SERVER_IP \
	--flannel-iface=$IFACE \
	--write-kubeconfig-mode=644 \
	--tls-san=$SERVER_IP" sh -

NODE=$(hostname | tr '[:upper:]' '[:lower:]')
kubectl wait --for=create node/"$NODE" --timeout=120s
kubectl wait --for=condition=Ready node/"$NODE" --timeout=120s

kubectl -n kube-system wait --for=create deploy/traefik --timeout=180s
kubectl -n kube-system rollout status deploy/traefik --timeout=180s

kubectl apply -f /vagrant/confs/

kubectl rollout status deploy/app1 --timeout=120s
kubectl rollout status deploy/app2 --timeout=120s
kubectl rollout status deploy/app3 --timeout=120s
kubectl get deploy,svc,ingress
