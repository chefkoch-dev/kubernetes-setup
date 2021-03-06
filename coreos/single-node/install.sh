#!/bin/bash

WORKDIR="$(pwd)"

MASTER_IP=$1
RETRIES=${2:-500}
K8S="${3:-1.4.6}"
HYPERKUBE_VERSION="${4:-v${K8S}_coreos.0}"

K8S_DASHBOARD="v1.4.2"
K8S_DNS="1.8"
K8S_DNSMASQ="1.4"
K8S_HEALTHZ="1.2"

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

#create kubernetes certificates
if [ ! -f "/etc/kubernetes/ssl/ca.pem" ]; then
    echo ">> Creating certificates"
    mkdir -p /etc/kubernetes/ssl
    cd /etc/kubernetes/ssl && bash ${WORKDIR}/certificates.sh "${MASTER_IP}"
    chmod 600 /etc/kubernetes/ssl/*-key.pem
    chown root:root /etc/kubernetes/ssl/*-key.pem
else
    echo ">> Skipping certificates"
fi

# create kubernetes manifest
if [ ! -f "/etc/kubernetes/manifests/kubernetes.yaml" ]; then
    echo ">> Preparing Kubernetes manifest"

    mkdir -p /etc/kubernetes/manifests

    sed -e "s@{{ADVERTISE_IP}}@${MASTER_IP}@" \
        -e "s@{{HYPERKUBE_VERSION}}@${HYPERKUBE_VERSION}@" \
        -e "s@{{K8S_DASHBOARD}}@${K8S_DASHBOARD}@" \
        -e "s@{{K8S_DNS}}@${K8S_DNS}@" \
        -e "s@{{K8S_DNSMASQ}}@${K8S_DNSMASQ}@" \
        -e "s@{{K8S_HEALTHZ}}@${K8S_HEALTHZ}@" \
        ${WORKDIR}/manifests/kubernetes.yaml > /etc/kubernetes/manifests/kubernetes.yaml
else
    echo ">> Skipping Kubernetes manifest"
fi


# install kubectl
if [ ! -f "/opt/bin/kubectl" ]; then
    echo ">> Downloading kubectl"
    mkdir -p /opt/bin
    wget -O /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${K8S}/bin/linux/amd64/kubectl
    chmod +x /opt/bin/kubectl
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

# install kubelet as systemd-unit
if [ ! -f "/etc/systemd/system/kubelet.service" ]; then
    echo ">> Preparing kubelet.service"

    sed \
      -e "s@{{K8S}}@${K8S}@" \
      -e "s@{{ADVERTISE_IP}}@${MASTER_IP}@" \
      -e "s@{{HYPERKUBE_VERSION}}@${HYPERKUBE_VERSION}@" \
      -e "s@{{K8S_DASHBOARD}}@${K8S_DASHBOARD}@" \
      -e "s@{{K8S_DNS}}@${K8S_DNS}@" \
      -e "s@{{K8S_DNSMASQ}}@${K8S_DNSMASQ}@" \
      -e "s@{{K8S_HEALTHZ}}@${K8S_HEALTHZ}@" \
      ${WORKDIR}/services/kubelet.service > /etc/systemd/system/kubelet.service
else
    echo ">> Skipping kubelet.service"
fi

echo ">> Starting Kubernetes"
systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet
systemctl status kubelet

echo ">> Waiting for Kubernetes to be ready"
command-wait "/opt/bin/kubectl cluster-info" ${RETRIES}

# kubernetes master is ready, now we are ready for installing addons
files=("dashboard-controller.yaml" "dashboard-np.yaml" "dashboard-service.yaml" "skydns-rc.yaml" "skydns-svc.yaml")
for i in ${files[@]}
do
    if [ ! -f "/etc/kubernetes/addons/${i}" ]; then
        mkdir -p /etc/kubernetes/addons
        echo ">> Installing addon ${i}"
        sed \
          -e "s@{{ADVERTISE_IP}}@${MASTER_IP}@" \
          -e "s@{{HYPERKUBE_VERSION}}@${HYPERKUBE_VERSION}@" \
          -e "s@{{K8S_DASHBOARD}}@${K8S_DASHBOARD}@" \
          -e "s@{{K8S_DNS}}@${K8S_DNS}@" \
          -e "s@{{K8S_DNSMASQ}}@${K8S_DNSMASQ}@" \
          -e "s@{{K8S_HEALTHZ}}@${K8S_HEALTHZ}@" \
          ${WORKDIR}/addons/${i} > /etc/kubernetes/addons/${i} \
          && /opt/bin/kubectl create -f /etc/kubernetes/addons/${i}
    else
        #@TODO check if addon is really installed
        echo ">> Skipping addon ${i}"
    fi
done
