#!/bin/bash
# installs every tool p3 needs: docker, kubectl, k3d, git

if [ "$(id -u)" -ne 0 ]; then
	echo "run me as root" >&2
	exit 1
fi

ARCH=$(dpkg --print-architecture)

command -v curl >/dev/null && command -v git >/dev/null ||
	{ apt-get update -qq && apt-get install -y -qq curl git ca-certificates; }

# docker: k3d runs the cluster nodes as containers, so it is the only hard dep
if ! command -v docker >/dev/null; then
	curl -fsSL https://get.docker.com | sh
	if [ -n "${SUDO_USER:-}" ]; then
		usermod -aG docker "$SUDO_USER"
		REOPEN=1
	fi
fi

# kubectl: whatever upstream currently marks as stable
if ! command -v kubectl >/dev/null; then
	VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
	curl -sLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$VERSION/bin/linux/$ARCH/kubectl"
	chmod +x /usr/local/bin/kubectl
fi

# k3d: runs a k3s cluster inside docker containers
command -v k3d >/dev/null ||
	curl -sL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# git: the v1 -> v2 demo pushes to the app repo from here
command -v git >/dev/null || { apt-get update -qq && apt-get install -y -qq git; }

TOOLS="docker kubectl k3d git"
for tool in $TOOLS; do
	command -v "$tool" >/dev/null || { echo "$tool missing" >&2; exit 1; }
done
echo "ready: $TOOLS"
