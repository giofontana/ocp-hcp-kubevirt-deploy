#!/bin/bash

# Current directory of the script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ask for cluster prefix name
read -p "Enter the base domain of the clusters (default: lab.gfontana.me): " base_domain
base_domain=${base_domain:-lab.gfontana.me}

read -p "Enter the cluster prefix name (default: ocp): " cluster_prefix_name
cluster_prefix_name=${cluster_prefix_name:-ocp}

read -p "Enter the number of clusters (default: 3): " cluster_number
cluster_number=${cluster_number:-3}

# Ask openshift credentials and url
read -p "Enter OpenShift API server URL of the Hub cluster (default: https://api.simpsons.lab.gfontana.me:6443): " server
server=${server:-https://api.simpsons.lab.gfontana.me:6443}

read -p "Enter OpenShift username of the Hub cluster (default: admin): " username
username=${username:-admin}

read -s -p "Enter OpenShift password of the Hub cluster: " password
echo

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

echo "Logging in to OpenShift Hub cluster..."
oc login -u $username -p $password --server=$server

echo "Deploying Clusters..."
cd ..
for i in $(seq 1 $cluster_number); do
    cluster_name="${cluster_prefix_name}${i}"
    echo "Deploying cluster: $cluster_name"

    echo "Deploying cluster $cluster_name using Helm chart..."
    helm install hcp-$cluster_name . \
        --set clusterName=$cluster_name \
        --set dns.baseDomain=$base_domain
done

# Wait for all clusters to be ready
for i in $(seq 1 $cluster_number); do
    cluster_name="${cluster_prefix_name}${i}"
    echo "Waiting for cluster $cluster_name to be ready..."
    timeout_seconds=7200
    interval_seconds=20
    elapsed_seconds=0

    while true; do
        history_states=$(oc get hostedcluster "$cluster_name" -n clusters -o jsonpath='{.status.version.history[*].state}' 2>/dev/null)

        if echo "$history_states" | grep -qw "Completed"; then
            echo "Cluster $cluster_name is ready (status.version.history.state=Completed)."
            break
        fi

        if [ $elapsed_seconds -ge $timeout_seconds ]; then
            echo "Timed out waiting for cluster $cluster_name to become ready."
            exit 1
        fi

        echo "Still waiting for $cluster_name... ($elapsed_seconds/${timeout_seconds}s)"
        sleep $interval_seconds
        elapsed_seconds=$((elapsed_seconds + interval_seconds))
    done
done

echo "----- All clusters are ready. -----"
echo 
echo "Proceeding with bootstrapping..."

temp_parent_dir=$(mktemp -d)
echo "Cloning GitOps repository..."
cd "$temp_parent_dir"
git clone https://github.com/giofontana/gitops-ocp-infra.git
cd gitops-ocp-infra

for i in $(seq 1 $cluster_number); do
    cluster_name="${cluster_prefix_name}${i}"

    echo "Logging in to cluster $cluster_name..."
    kubeconfig_secret_name=$(oc get hostedcluster "$cluster_name" -n clusters -o jsonpath='{.status.kubeconfig.name}')

    if [ -z "$kubeconfig_secret_name" ]; then
        echo "Could not find status.kubeconfig.name for cluster $cluster_name."
        exit 1
    fi

    temp_dir=$temp_parent_dir/$cluster_name
    mkdir -p "$temp_dir"
    temp_kubeconfig="$temp_dir/kubeconfig"

    oc get secret "$kubeconfig_secret_name" -n clusters -o jsonpath='{.data.kubeconfig}' | base64 -d > "$temp_kubeconfig"

    echo "Bootstrapping cluster $cluster_name with Argo CD..."
    "$script_dir/bootstrap.sh" "$cluster_name" "$temp_parent_dir" "$temp_kubeconfig"
    
    echo "Bootstrap process for cluster $cluster_name completed."
    echo "------------------------------------------------------------"
done

rm -rf "$temp_parent_dir"