#!/bin/bash

# Current directory of the script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

echo "Uninstalling Clusters..."
cd ..
for i in $(seq 1 $cluster_number); do
    cluster_name="${cluster_prefix_name}${i}"
    echo "Uninstalling cluster: $cluster_name"

    echo "Uninstalling cluster $cluster_name using Helm chart..."
    helm uninstall hcp-$cluster_name
done
