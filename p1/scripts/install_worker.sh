#!/bin/bash
# k3s agent, joins the server

SERVER_IP="$1"
WORKER_IP="$2"

IFACE=$(ip -o -4 addr show | awk -v ip="$WORKER_IP/" '$4 ~ ip {print $2; exit}')
if [ -z "$IFACE" ]; then
	echo "no interface holds $WORKER_IP" >&2
	ip -o -4 addr show >&2
	exit 1
fi
echo "private iface: $IFACE"

if [ ! -f /vagrant/.secrets/node-token ]; then
	echo "token missing, server not provisioned yet" >&2
	exit 1
fi

curl -sfL https://get.k3s.io | \
	K3S_URL="https://$SERVER_IP:6443" \
	K3S_TOKEN="$(cat /vagrant/.secrets/node-token)" \
	INSTALL_K3S_EXEC="agent \
		--node-ip=$WORKER_IP \
		--flannel-iface=$IFACE" sh -

systemctl is-active k3s-agent
