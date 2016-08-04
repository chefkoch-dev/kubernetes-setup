#!/bin/bash

MASTER_IP=$1
RETRIES=${2:-500}

if [ -z "${MASTER_IP}" ]; then
    echo "ERROR: No IP parameter given"
    echo "Usage:"
    echo "bash $0 <master_ip>"
    exit 1
fi

if [ "${SUDO}" = "1" ]; then
    SUDO="sudo"
else
    SUDO=""
fi

function command-wait {
    retries=$2
    cnt=0
    set +e
    echo "Waiting for command '$1' doing $retries retries"
    while [ $cnt -lt $retries ]
    do
        echo -n "."
        eval "$1" &> /dev/null
        result=$?

        if [ "$result" -lt 1 ]; then
            echo ""
            echo "Command was successfull"
            sleep 2
            return 0
        fi

        ((cnt++));
        sleep 1
    done

    set -e

    echo "Command failed in time ($retries retries)."

    return 1
}

echo ">> Preparing folders"
$SUDO mkdir -p /etc/kubernetes/ssl /opt/bin /etc/kubernetes/manifests/

echo ">> Creating certificates"
wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/single-node/certificates.sh
bash ./certificates.sh "${MASTER_IP}"

echo ">> Installing certificates"
$SUDO cp ca.pem /etc/kubernetes/ssl/
$SUDO cp apiserver.pem /etc/kubernetes/ssl/
$SUDO cp apiserver-key.pem /etc/kubernetes/ssl/
$SUDO chmod 600 /etc/kubernetes/ssl/*-key.pem
$SUDO chown root:root /etc/kubernetes/ssl/*-key.pem

echo ">> Preparing kubelet.service"
wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/single-node/services/kubelet.service
$SUDO cp kubelet.service /etc/systemd/system/kubelet.service

echo ">> Preparing Kubernetes manifest"
wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/single-node/manifests/kubernetes.yaml

sed -i "s@{{ADVERTISE_IP}}@${MASTER_IP}@" kubernetes.yaml

$SUDO cp kubernetes.yaml /etc/kubernetes/manifests/

echo ">> Downloading kubectl"
$SUDO wget -O /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.3.2/bin/linux/amd64/kubectl
$SUDO chmod +x /opt/bin/kubectl

kubectl config set-cluster default-cluster --server=http://${MASTER_IP}:8080
kubectl config set-context default-system --cluster=default-cluster
kubectl config use-context default-system

echo ">> Starting Kubernetes"
$SUDO systemctl daemon-reload
$SUDO systemctl start kubelet
$SUDO systemctl enable kubelet
$SUDO systemctl status kubelet

echo ">> Waiting for Kubernetes to be ready"
command-wait "kubectl cluster-info" ${RETRIES}
