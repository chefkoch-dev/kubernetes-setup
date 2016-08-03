# Kubernetes Setup

## Single-Node Setup

Howto for setting up a single-node Kubernetes (v.1.3.2) on a CoreOS machine.
All steps should be executed with the default `core` user with sudo permissions.

Requirements for this setup:

* CoreOS >= 773.1.0
* etcd installed and running
    * single-node
    * Client URL: http://127.0.0.1:2379

Initial setup

    sudo mkdir -p /etc/kubernetes/ssl /opt/bin /etc/kubernetes/manifests/
    
Creating the self-signed certificates

    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/single-node/certificates.sh    
    bash ./certificates.sh <public ip of your machine>
    
    sudo cp ca.pem /etc/kubernetes/ssl/
    sudo cp apiserver.pem /etc/kubernetes/ssl/
    sudo cp apiserver-key.pem /etc/kubernetes/ssl/
    sudo chmod 600 /etc/kubernetes/ssl/*-key.pem
    sudo chown root:root /etc/kubernetes/ssl/*-key.pem    
    
Defining the kubelet service (with `privileged` mode enabled)

    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/single-node/services/kubelet.service
    sudo cp kubelet.service /etc/systemd/system/kubelet.service
    
Preparing the Kubernetes manifest

    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/single-node/manifests/kubernetes.yaml
    
    sed -i "s@{{ADVERTISE_IP}}@<public ip of your machine>@" kubernetes.yaml
    
    sudo cp kubernetes.yaml /etc/kubernetes/manifests/
    
Install kubectl

    sudo wget -O /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.3.2/bin/linux/amd64/kubectl
    sudo chmod +x /opt/bin/kubectl
    
Start Kubernetes

    sudo systemctl daemon-reload
    sudo systemctl start kubelet
    sudo systemctl enable kubelet
    sudo systemctl status kubelet
    
    
Check if everything works correctly

    kubectl cluster-info
    kubectl run nginx --image=nginx
    kubectl get pods
    
For the lazy ones all steps combined in an installer

    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/single-node/install.sh
    # for the paranoid ones: check contents of this script
    # cat install.sh
    bash ./install.sh

## Further Documentation

* [CoreOS + Kubernetes Step By Step](https://coreos.com/kubernetes/docs/latest/getting-started.html)
* [Cluster TLS using OpenSSL](https://coreos.com/kubernetes/docs/latest/openssl.html)
* [Introducing the Kubernetes kubelet in CoreOS Linux](https://coreos.com/blog/introducing-the-kubelet-in-coreos/)
* [Deploy Kubernetes Master Node(s)](https://coreos.com/kubernetes/docs/latest/deploy-master.html)
