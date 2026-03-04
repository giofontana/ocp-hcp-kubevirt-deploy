#!/bin/bash

cluster_name="$1"
temp_dir="$2"
temp_kubeconfig="$3"

if [ -z "$cluster_name" ] || [ -z "$temp_dir" ] || [ -z "$temp_kubeconfig" ]; then
    echo "Usage: ./bootstrap.sh <cluster_name> <temp_dir> <temp_kubeconfig>"
    exit 1
fi

if [ ! -f "$temp_kubeconfig" ]; then
    echo "Kubeconfig file not found: $temp_kubeconfig"
    exit 1
fi

# Check if oc CLI is installed
if ! command -v oc &> /dev/null; then
    echo "oc CLI could not be found. Please install it and try again."
    exit 1
fi

# Check if helm CLI is installed
if ! command -v helm &> /dev/null; then
    echo "helm CLI could not be found. Please install it and try again."
    exit 1
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "git CLI could not be found. Please install it and try again."
    exit 1
fi

# Check if provided kubeconfig can authenticate
if ! oc --kubeconfig="$temp_kubeconfig" whoami &> /dev/null; then
    echo "Cannot authenticate with provided kubeconfig: $temp_kubeconfig"
    exit 1
fi

cluster_console_url=$(oc --kubeconfig="$temp_kubeconfig" get console cluster -o jsonpath='{.status.consoleURL}')
echo "Successfully authenticated to cluster. Console URL: $cluster_console_url"

########
echo "Deploying Sealed Secrets Operator..."
oc --kubeconfig="$temp_kubeconfig" create -k gitops/manifests/operators/sealed-secrets-operator/operator/overlays/default
# Wait for the sealed-secrets-operator to be ready
oc --kubeconfig="$temp_kubeconfig" wait --for=condition=available --timeout=120s deployment/sealed-secrets-controller -n sealed-secrets
#######

#######
echo "Replacing Sealed Secrets secret..."
echo "WARNING: Deleting existing secrets in 8 seconds..."
echo
oc --kubeconfig="$temp_kubeconfig" get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key
sleep 8

oc --kubeconfig="$temp_kubeconfig" delete secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key
echo "Creating secret from local drive."
oc --kubeconfig="$temp_kubeconfig" create -f ~/.bitnami/sealed-secrets-secret.yaml -n sealed-secrets
echo "Restarting Sealed Secrets controller."
oc --kubeconfig="$temp_kubeconfig" delete pod -l name=sealed-secrets-controller -n sealed-secrets

# Wait for the sealed-secrets-controller to be ready after the secret replacement
oc --kubeconfig="$temp_kubeconfig" wait --for=condition=available --timeout=120s deployment/sealed-secrets-controller -n sealed-secrets
#########

#########
echo "Deploying Argo CD..."
oc --kubeconfig="$temp_kubeconfig" apply -k gitops/manifests/clusters/all/aggregate/openshift-gitops

# Wait for the Argo CD application controller StatefulSet to be ready
oc --kubeconfig="$temp_kubeconfig" patch consoles.operator.openshift.io/cluster --type='merge' -p '{"spec":{"plugins":["gitops-plugin"]}}'

oc --kubeconfig="$temp_kubeconfig" rollout status statefulset/openshift-gitops-application-controller -n openshift-gitops --timeout=120s
oc --kubeconfig="$temp_kubeconfig" patch argocd openshift-gitops -n openshift-gitops  --type json -p '[{"op": "replace", "path": "/spec/controller/resources/limits/memory", "value": "8Gi"}]'
#########

#########
echo "Deploying Argo App of Apps for cluster $cluster_name..."
oc --kubeconfig="$temp_kubeconfig" apply -k gitops/manifests/clusters/$cluster_name/bootstrap/stable
#########

#########
argocd_uri=$(oc --kubeconfig="$temp_kubeconfig" get route -n openshift-gitops openshift-gitops-server -o jsonpath='{.spec.host}')
argocd_username="admin"
argocd_initial_password=$(oc --kubeconfig="$temp_kubeconfig" -n openshift-gitops get secret openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' | base64 --decode)

echo "Bootstrap process for cluster $cluster_name completed. Please check Argo CD for application synchronization status."
echo "You can access the Argo CD UI at: https://$argocd_uri"
echo "Username: $argocd_username"
echo "Initial Password: $argocd_initial_password"
#########