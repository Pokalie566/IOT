#!/bin/bash
# k3s server + publish node token

SERVER_IP="$1"

IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP/" '$4 ~ ip {print $2; exit}')
if [ -z "$IFACE" ]; then
	echo "no interface holds $SERVER_IP" >&2
	ip -o -4 addr show >&2
	exit 1
fi
echo "private iface: $IFACE"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
	--node-ip=$SERVER_IP \
	--advertise-address=$SERVER_IP \
	--flannel-iface=$IFACE \
	--write-kubeconfig-mode=644 \
	--tls-san=$SERVER_IP" sh -

mkdir -p /vagrant/.secrets
cp /var/lib/rancher/k3s/server/node-token /vagrant/.secrets/node-token

NODE=$(hostname | tr '[:upper:]' '[:lower:]')

# --for=create: API server just booted, Node object may not exist yet
kubectl wait --for=create node/"$NODE" --timeout=120s
kubectl wait --for=condition=Ready node/"$NODE" --timeout=120s
kubectl get nodes -o wide
