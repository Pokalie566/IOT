#!/bin/bash
# installs every tool p3 needs: docker, kubectl, k3d, helm, argocd
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

# helm: not needed by p3 itself, required by the bonus
command -v helm >/dev/null ||
	curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# argocd cli: reads the admin password and forces a sync without the ui
if ! command -v argocd >/dev/null; then
	curl -sLo /usr/local/bin/argocd \
		"https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-$ARCH"
	chmod +x /usr/local/bin/argocd
fi

for tool in docker kubectl k3d helm argocd; do
	command -v "$tool" >/dev/null || { echo "$tool missing" >&2; exit 1; }
	echo "ok: $tool"
done
