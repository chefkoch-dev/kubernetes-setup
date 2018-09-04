#!/bin/bash
# Usage:
# Run this script with root!
#
# ./install.sh [<kubernetes_version>] [<target_user>] [<port_range>]

k8s_version=${1:-"v1.10.0"}
target_user=${2:-ubuntu}
port_range=${3:-"80-32767"}

export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export CHANGE_MINIKUBE_NONE_USER=true
export MINIKUBE_HOME=/home/${target_user}
export KUBECONFIG=/home/${target_user}/.kube/config

mkdir -p /home/${target_user}/.kube || true
touch /home/${target_user}/.kube/config

minikube start \
    --kubernetes-version "${k8s_version}" \
    --extra-config=apiserver.ServiceNodePortRange="${port_range}" \
    --logtostderr --loglevel 0 \
    --vm-driver=none

minikube config set WantKubectlDownloadMsg false
minikube config set WantReportErrorPrompt false

# enable addons
minikube addons enable dashboard

# fix file permissions after minikube has created meta files
chown ${target_user}:${target_user} -R /home/${target_user}/.kube
chown ${target_user}:${target_user} -R /home/${target_user}/.minikube
