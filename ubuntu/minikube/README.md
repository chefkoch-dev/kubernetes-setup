# Kubernetes installation on Ubuntu

Single-node Kubernetes installation done with the help of Minikube and localkube.


## Testing
Manual testing could be done with the help of a vagrant box.

    vagrant up
    vagrant ssh
    
The setup generates a kubeconfig for the ubuntu user by default. Either sudo to this user to communicate with Kubernetes or just do
    
    sudo -H -u ubuntu kubectl get nodes
    

## Internal
Two scripts are used for this setup.

* `provision.sh` provisions the vagrant box. It prepares everything for Minikube.
* `install.sh` installs Kubernetes with the help of Minikube.

Both scripts are executed on the first boot of the vagrant box.
