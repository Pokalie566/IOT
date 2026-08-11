#!/bin/bash
# installs every tool p3 needs: docker, kubectl, k3d, git
# target: debian/ubuntu, run as root

if [ "$(id -u)" -ne 0 ]; then
	echo "run me as root" >&2
	exit 1
fi

ARCH=$(dpkg --print-architecture)

# docker: k3d runs the cluster nodes as containers, so it is the only hard dep
if ! command -v docker >/dev/null; then
	curl -fsSL https://get.docker.com | sh
	# only when invoked through sudo: give that user docker without sudo
	[ -n "${SUDO_USER:-}" ] && usermod -aG docker "$SUDO_USER"
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

for tool in docker kubectl k3d git; do
	command -v "$tool" >/dev/null || { echo "$tool missing" >&2; exit 1; }
	echo "ok: $tool"
done
