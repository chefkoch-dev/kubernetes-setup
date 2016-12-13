# Kubernetes Setup

Disclaimer: The installation script is a moving target. Path and workflow may change in near future.

## CoreOS

### Single-Node Setup

Howto for setting up a single-node Kubernetes on a CoreOS machine.
All steps should be executed with the default `core` user with sudo permissions.

This setup is only for dev or test purposes. Don't use this in production as the Kubernetes API will be publicy available.

Requirements for this setup:

* CoreOS >= 773.1.0
* etcd installed and running
    * single-node
    * Client URL: http://127.0.0.1:2379

Initial setup

    sudo mkdir -p /etc/kubernetes/ssl /opt/bin /etc/kubernetes/manifests/

Creating the self-signed certificates

    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/coreos/single-node/certificates.sh
    bash ./certificates.sh <public ip of your machine>

    sudo cp ca.pem /etc/kubernetes/ssl/
    sudo cp apiserver.pem /etc/kubernetes/ssl/
    sudo cp apiserver-key.pem /etc/kubernetes/ssl/
    sudo chmod 600 /etc/kubernetes/ssl/*-key.pem
    sudo chown root:root /etc/kubernetes/ssl/*-key.pem

Defining the kubelet service (with `privileged` mode enabled)

    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/coreos/single-node/services/kubelet.service
    sudo cp kubelet.service /etc/systemd/system/kubelet.service

Preparing the Kubernetes manifest

    wget https://raw.githubusercontent.com/chefkoch-dev/kubernetes-setup/master/coreos/single-node/manifests/kubernetes.yaml

    sed -i "s@{{ADVERTISE_IP}}@<public ip of your machine>@" kubernetes.yaml

    sudo cp kubernetes.yaml /etc/kubernetes/manifests/

Install kubectl

    sudo wget -O /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/<release>/bin/linux/amd64/kubectl
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

    # Step 1
    ```
    ~> wget https://github.com/chefkoch-dev/kubernetes-setup/archive/master.tar.gz -O /tmp/master.tar.gz
    ~> cd /tmp && tar xvf master.tar.gz
    ~> cd kubernetes-setup-master 
    ```
    # for the paranoid ones: check contents of this script
    # cat install.sh

    # Step 2.1
    # execute as root
    bash ./install.sh $MASTER_IP

    # Step 2.2
    # execute as non-root
    export SUDO=1; bash ./install.sh

## Further Documentation

* [CoreOS + Kubernetes Step By Step](https://coreos.com/kubernetes/docs/latest/getting-started.html)
* [Cluster TLS using OpenSSL](https://coreos.com/kubernetes/docs/latest/openssl.html)
* [Introducing the Kubernetes kubelet in CoreOS Linux](https://coreos.com/blog/introducing-the-kubelet-in-coreos/)
* [Deploy Kubernetes Master Node(s)](https://coreos.com/kubernetes/docs/latest/deploy-master.html)
* [Kubernetes Reference Documentation](http://kubernetes.io/docs/admin/kube-apiserver/)
* [Deploy the DNS Add-on](https://coreos.com/kubernetes/docs/latest/deploy-addons.html)
