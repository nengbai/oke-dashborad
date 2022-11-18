#!/bin/bash
# author: nengbai@aliyun.com
# bash create_cert.sh oke-admin  dashboard example.com kubernetes-dashboard

if [ $# -ne 4 ];then
    echo "please user in: `basename $0` SECRET_NAME CERT_NAME DOMAIN NAMESPACE"
    exit 1
fi

SECRET_NAME=$1
CERT_NAME=$2
DOMAIN=$3
NAMESPACE=$4

# TLS Secrets
# Anytime we reference a TLS secret, we mean a PEM-encoded X.509, RSA (2048) secret.
# You can generate a self-signed certificate and private key with:

# openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout ${CERT_NAME}.key -out ${CERT_NAME}.crt -subj "/CN=${DOMAIN}/O=${DOMAIN}"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout ${CERT_NAME}.key -out ${CERT_NAME}.crt -subj "/CN=${DOMAIN}/O=${DOMAIN}"

# 创建 NAMESPACE
kubectl get namespace |grep ${NAMESPACE}
if [ $? -eq 0 ]; then
     echo "[INFO] ${NAMESPACE} is already exists"
else
     kubectl create namespace ${NAMESPACE}
     echo "[INFO] create ${NAMESPACE} success!"
fi

# Then create the secret in the cluster via:
# kubectl create secret tls ${SECRET_NAME} --key ${CERT_NAME}.key --cert ${CERT_NAME}.crt
# 如果你使用--key --cert方式则创建的secret中data的默认2个文件名就是tls.key和tls.crt

kubectl create secret generic ${SECRET_NAME} --from-file=${CERT_NAME}.crt --from-file=${CERT_NAME}.key -n ${NAMESPACE}
# The resulting secret will be of type kubernetes.io/tls.
