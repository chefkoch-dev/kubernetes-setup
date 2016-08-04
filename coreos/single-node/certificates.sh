#!/bin/bash
#
# Script based on
# * https://coreos.com/kubernetes/docs/latest/getting-started.html
# * https://coreos.com/kubernetes/docs/latest/openssl.html
#

MASTER_HOST=$1
WORKERS=""
K8S_SERVICE_IP="10.3.0.1"

if [ -z "${MASTER_HOST}" ]; then
    echo "ERROR: No MASTER_HOST parameter given"
    echo "Usage:"
    echo "bash $0 <master_host>"
    exit 1
fi

#Create a Cluster Root CA
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube-ca"
chmod 0600 ca-key.pem


if [ ! -f openssl.cnf ]; then
    cat >openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = ${K8S_SERVICE_IP}
IP.2 = ${MASTER_HOST}
EOF
fi

if [ ! -f apiserver-key.pem ]; then
    openssl genrsa -out apiserver-key.pem 2048
    openssl req -new -key apiserver-key.pem -out apiserver.csr -subj "/CN=kube-apiserver" -config openssl.cnf
    openssl x509 -req -in apiserver.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out apiserver.pem -days 365 -extensions v3_req -extfile openssl.cnf
fi


# Kubernetes Worker Keypairs
if [ ! -f worker-openssl.cnf ]; then
cat >openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = $ENV::WORKER_IP
EOF
fi

for WORKER in ${WORKERS}; do
    if [ ! -f ${WORKER}-worker-key.pem ]; then
        WORKER_IP=$(host ${WORKER}|grep "has address"|sed -e 's/.*\s//')
        if [ -n "${WORKER_IP}" ]; then
            export WORKER_IP=${WORKER_IP}
            openssl genrsa -out ${WORKER}-worker-key.pem 2048
            openssl req -new -key ${WORKER}-worker-key.pem -out ${WORKER}-worker.csr -subj "/CN=${WORKER}" -config worker-openssl.cnf
            openssl x509 -req -in ${WORKER}-worker.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out ${WORKER}-worker.pem -days 365 -extensions v3_req -extfile worker-openssl.cnf
        fi
    fi
done

#Generate the Cluster Administrator Keypair
if [ ! -f admin-key.pem ]; then
    openssl genrsa -out admin-key.pem 2048
    openssl req -new -key admin-key.pem -out admin.csr -subj "/CN=kube-admin"
    openssl x509 -req -in admin.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out admin.pem -days 365
fi
