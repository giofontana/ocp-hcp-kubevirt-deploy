# OpenShift HyperShift HCP Helm Chart

A Helm chart for deploying OpenShift HyperShift Hosted Control Planes with full parameterization to support multiple clusters.

## Overview

This chart deploys the complete HyperShift infrastructure including:
- HostedCluster resource
- NodePool configuration  
- ManagedCluster registration
- KlusterletAddonConfig
- Secret synchronization job
- Required namespaces and RBAC

All references to cluster names (like `ocp1`) are parameterized through the `clusterName` value, making these manifests fully reusable across different clusters.

## Chart Structure

```
hcp-helm/
├── Chart.yaml
├── values.yaml
├── README.md
└── templates/
    ├── namespace.yaml
    ├── hostedcluster.yaml
    ├── nodepool.yaml
    ├── managedcluster.yaml
    ├── klusterlet.yaml
    └── secret-sync-job.yaml
```

## Usage

### Deploy for `ocp1` (default)

```bash
helm install hcp-ocp1 .
```

### Deploy for a different cluster (e.g., `ocp2`)

```bash
helm install hcp-ocp2 . \
  --set clusterName=ocp2 \
  --set dns.baseDomain=lab.gfontana.me
```

For a fresh install where namespaces do not exist yet, enable namespace creation:

```bash
helm install hcp-ocp2 . \
  --set clusterName=ocp2 \
  --set createInfraNamespaces=true # To create the hosted cluster namespace, eg.: clusters
  --set createClusterNamespace=true # To create the managed cluster namespace, eg.: clusters-ocp2
```

### Dry-run to see rendered manifests

```bash
helm template hcp-ocp1 . \
  --set clusterName=ocp1 \
  --values values.yaml
```

## Customization

Edit `values.yaml` to customize:

- **clusterName**: The name of the cluster (default: `ocp1`)
- **dns.baseDomain**: Base domain for DNS (default: `lab.gfontana.me`)
- **release.image**: OpenShift release image
- **HostedCluster**: Networking, ETCD, platform, and availability settings
- **NodePool**: Compute resources, storage, and network configuration
- **KlusterletAddon**: Features for cluster management and monitoring
- **secretsSource**: Source secret for pull credentials

### Example: Override cluster name

```bash
helm install hcp-ocp4 . \
  --set clusterName=ocp4
```

All `ocp1` references in the templates will be automatically replaced with `ocp4`.

### Example: Override networking

```bash
helm install hcp-custom . \
  --set clusterName=custom-cluster \
  --set networking.clusterNetwork[0].cidr=10.200.0.0/14 \
  --set networking.serviceNetwork[0].cidr=172.40.0.0/16
```

## Parameterized Values

All cluster-specific values can be overridden at install/upgrade time:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `clusterName` | `ocp1` | Cluster identifier used throughout manifests |
| `infraCluster.namespace` | `clusters` | Namespace for cluster resources |
| `dns.baseDomain` | `lab.gfontana.me` | Base domain for DNS |
| `release.image` | `quay.io/openshift-release-dev/ocp-release:4.20.14-multi` | OpenShift release image |
| `nodePool.replicas` | `1` | Number of node pool replicas |
| `nodePool.compute.cores` | `8` | CPU cores per node |
| `nodePool.compute.memory` | `32Gi` | Memory per node |
| `nodePool.rootVolume.size` | `100Gi` | Root volume size |

## Generated Resources

### Namespace
- `clusters` - Infrastructure cluster namespace
- `{{ clusterName }}` - Cluster-specific namespace (e.g., `ocp1`)

### HostedCluster & NodePool
- Creates a HyperShift HostedCluster resource
- Creates corresponding NodePool for worker nodes
- Configures KubeVirt as the hypervisor platform
- Sets up storage mapping for guest and infrastructure storage classes

### Managed Cluster
- Registers cluster with Red Hat Advanced Cluster Management (ACM)
- Configures hosted klusterlet deployment mode
- Adds cluster labels for management

### Secret Sync Job
- Syncs pull secret and SSH key from source secret
- Runs as a Kubernetes Job with automatic cleanup
- Supports multi-cluster credential management

## Prerequisites

- Kubernetes cluster with HyperShift enabled
- KubeVirt or another hypervisor platform
- OpenShift Container Storage (OCS) configured
- Source secret in `open-cluster-management-credentials` namespace

## Troubleshooting

### Check rendered templates without deploying

```bash
helm template my-release . --set clusterName=my-cluster
```

### Validate chart structure

```bash
helm lint .
```

### Debug template variables

```bash
helm get values my-release
```

## License

Same as parent project
