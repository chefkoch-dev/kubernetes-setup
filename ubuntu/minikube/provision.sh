#!/bin/bash

# Step 1: docker installation
# @see https://docs.docker.com/engine/installation/linux/ubuntu/#install-using-the-repository
apt-get update && apt-get install -yq \
    apt-transport-https \
    curl \
    ca-certificates \
    openssh-client \
    software-properties-common \
    --no-install-recommends

# prepare ubuntu user
groupadd ubuntu
adduser ubuntu ubuntu -shell /bin/bash

# install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update

apt-get install -yq docker-ce=17.09.1~ce-0~ubuntu

# pre-installation steps for Docker on linux
groupadd docker || true
usermod -aG docker ubuntu

# install kubectl
kubectl_file=/usr/local/bin/kubectl
curl -L "https://storage.googleapis.com/kubernetes-release/release/v1.10.0/bin/linux/amd64/kubectl" -o "${kubectl_file}" && chmod +x "${kubectl_file}"

# install minikube
minikube_file=/usr/local/bin/minikube
curl -L "https://github.com/kubernetes/minikube/releases/download/v0.28.2/minikube-linux-amd64" -o "${minikube_file}" && chmod +x "${minikube_file}"
