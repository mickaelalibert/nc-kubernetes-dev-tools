#!/bin/bash -e

# Usage ./k8s-service-account-kubeconfig.sh ( namespace ) ( service account name )

NS=$1
SA=$2

TEMPDIR=$( mktemp -d )

trap "{ rm -rf $TEMPDIR ; exit 255; }" EXIT

SA_SECRET=$( kubectl get sa -n ${NS} ${SA} -o jsonpath='{.secrets[0].name}' )

# Pull the bearer token and cluster CA from the service account secret.
BEARER_TOKEN=$( kubectl get secrets -n ${NS} $SA_SECRET -o jsonpath='{.data.token}' | base64 -d )
kubectl get secrets -n ${NS} $SA_SECRET -o jsonpath='{.data.ca\.crt}' | base64 -d > $TEMPDIR/ca.crt

CLUSTER_URL="https://$(gcloud container clusters describe nc-kubedev --format json | jq -r '.endpoint')"


KUBECONFIG=kubeconfig

rm -f $KUBECONFIG

kubectl config --kubeconfig=$KUBECONFIG \
    set-cluster \
    $CLUSTER_URL \
    --server=$CLUSTER_URL \
    --certificate-authority=$TEMPDIR/ca.crt \
    --embed-certs=true 1>/dev/null

kubectl config --kubeconfig=$KUBECONFIG \
    set-credentials ${SA} --token=$BEARER_TOKEN 1>/dev/null

kubectl config --kubeconfig=$KUBECONFIG \
    set-context registry \
    --cluster=$CLUSTER_URL \
    --user=${SA} 1>/dev/null

kubectl config --kubeconfig=$KUBECONFIG \
    use-context registry 1>/dev/null