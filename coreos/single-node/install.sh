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
$SUDO mkdir -p /etc/kubernetes/ssl /opt/bin /etc/kubernetes/manifests /etc/kubernetes/addons

if [ ! -f "/etc/kubernetes/ssl/ca.pem" ]; then
    echo ">> Creating certificates"
    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/coreos/single-node/certificates.sh
    bash ./certificates.sh "${MASTER_IP}"

    echo ">> Installing certificates"
    $SUDO cp ca.pem /etc/kubernetes/ssl/
    $SUDO cp apiserver.pem /etc/kubernetes/ssl/
    $SUDO cp apiserver-key.pem /etc/kubernetes/ssl/
    $SUDO chmod 600 /etc/kubernetes/ssl/*-key.pem
    $SUDO chown root:root /etc/kubernetes/ssl/*-key.pem
else
    echo ">> Skipping certificates"
fi

if [ ! -f "/opt/bin/kubelet" ]; then
    echo ">> Downloading kubelet"
    $SUDO wget -O /opt/bin/kubelet https://storage.googleapis.com/kubernetes-release/release/v1.4.6/bin/linux/amd64/kubelet
    $SUDO chmod +x /opt/bin/kubelet
else
    echo ">> Skipping kubectl"
fi

if [ ! -f "/etc/systemd/system/kubelet.service" ]; then
    echo ">> Preparing kubelet.service"
    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/coreos/single-node/services/kubelet.service
    $SUDO cp kubelet.service /etc/systemd/system/kubelet.service
else
    echo ">> Skipping kubelet.service"
fi

if [ ! -f "/etc/kubernetes/manifests/kubernetes.yaml" ]; then
    echo ">> Preparing Kubernetes manifest"
    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/coreos/single-node/manifests/kubernetes.yaml

    sed -i "s@{{ADVERTISE_IP}}@${MASTER_IP}@" kubernetes.yaml

    $SUDO cp kubernetes.yaml /etc/kubernetes/manifests/
else
    echo ">> Skipping Kubernetes manifest"
fi

if [ ! -f "/opt/bin/kubectl" ]; then
    echo ">> Downloading kubectl"
    $SUDO wget -O /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.4.6/bin/linux/amd64/kubectl
    $SUDO chmod +x /opt/bin/kubectl
else
    echo ">> Skipping kubectl"
fi

# systemd is running outside of sessions, so the default location ${HOME}/.kube/config does not work
if [ ! -f "/tmp/kubeconfig" ]; then
    echo ">> Defining Kubernetes context"
    export KUBECONFIG=/tmp/kubeconfig
    /opt/bin/kubectl config set-cluster default-cluster --server=http://${MASTER_IP}:8080
    /opt/bin/kubectl config set-context default-system --cluster=default-cluster
    /opt/bin/kubectl config use-context default-system
else
    echo ">> Skipping Kubernetes context"
fi

echo ">> Starting Kubernetes"
$SUDO systemctl daemon-reload
$SUDO systemctl start kubelet
$SUDO systemctl enable kubelet
$SUDO systemctl status kubelet

echo ">> Waiting for Kubernetes to be ready"
command-wait "/opt/bin/kubectl cluster-info" ${RETRIES}

# kubernetes master is ready, now we are ready for installing addons
files=("dashboard-controller.yaml" "dashboard-np.yaml" "dashboard-service.yaml" "skydns-rc.yaml" "skydns-svc.yaml")
for i in ${files[@]}
do
    if [ ! -f "/etc/kubernetes/addons/${i}" ]; then
        echo ">> Installing addon ${i}"
        $SUDO wget -O /etc/kubernetes/addons/${i} https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/coreos/single-node/addons/${i}
        /opt/bin/kubectl create -f /etc/kubernetes/addons/${i}
    else
        #@TODO check if addon is really installed
        echo ">> Skipping addon ${i}"
    fi
done
