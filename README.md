# Integration Platform Demo

A complete integration platform demo showcasing event-driven architecture with Redpanda, deployed via Flux GitOps on a multinode k3d cluster.

## Overview

This demo platform includes:

- **Infrastructure**: Redpanda (Kafka-compatible), PostgreSQL, Redis
- **Core Services**: API Gateway (Kong), HTTP Adapter, Transform Service, Router Service
- **Management Portal**: Web-based UI for managing integrations
- **Sample Integrations**: HTTP-to-Kafka, File Processor, Database Sync
- **Monitoring**: Prometheus, Grafana, Loki for metrics and logs
- **GitOps**: Flux CD for declarative infrastructure management

## Architecture

The platform follows an event-driven architecture where:

1. External systems send data via HTTP to the API Gateway
2. HTTP Adapter publishes events to Redpanda topics
3. Transform Service processes and transforms messages
4. Router Service orchestrates message routing
5. Integration services consume from Redpanda and perform business logic
6. All components are monitored via Prometheus and Grafana

## Quick Start

### Prerequisites

Before running this demo, ensure you have the following tools installed on your computer:

#### Required Tools

1. **Docker** (v20.10+)
   - Install: https://docs.docker.com/get-docker/
   - Verify: `docker --version`

2. **kubectl** (v1.24+)
   - Install: https://kubernetes.io/docs/tasks/tools/
   - Verify: `kubectl version --client`

3. **k3d** (v5.0.0+)
   - Install: `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`
   - Or via package manager: `brew install k3d` (macOS) or `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash` (Linux)
   - Verify: `k3d version`

4. **flux CLI** (v2.0.0+)
   - Install: `curl -s https://fluxcd.io/install.sh | bash`
   - Verify: `flux version`

#### System Requirements

- **OS**: Linux, macOS, or Windows (with WSL2)
- **RAM**: Minimum 8GB (16GB recommended)
- **CPU**: 4+ cores recommended
- **Disk**: 10GB free space

### Setup Steps

Follow these steps to run the demo on your local computer:

1. **Fork and clone the repository**:
   - **Important**: You need to fork this repository to your own GitHub account because Flux needs write access to commit Flux system manifests back to the repository during bootstrap.
   - Fork the repository on GitHub, then clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/integration-platform-demo.git
   cd integration-platform-demo
   ```
   (Replace `YOUR_USERNAME` with your GitHub username and `integration-platform-demo` with your actual repository name if different)

2. **Make scripts executable**:
   ```bash
   chmod +x scripts/*.sh
   ```

3. **Create k3d cluster**:
   ```bash
   ./scripts/setup-k3d.sh
   ```
   This will create a 3-node k3d cluster named `integration-platform`. The script will:
   - Delete any existing cluster with the same name
   - Create a new cluster with 3 agent nodes
   - Configure port forwarding (8080:80, 8443:443)
   - Wait for all nodes to be ready

4. **Bootstrap Flux**:
   ```bash
   export GITHUB_USER=your-github-username
   export GITHUB_REPO=integration-platform-demo  # Optional: defaults to "integration-platform"
   ./scripts/bootstrap-flux.sh
   ```
   
   **Important**: 
   - Set `GITHUB_USER` to your GitHub username. The script will automatically configure the GitRepository URL.
   - If your repository name differs from `integration-platform-demo`, set `GITHUB_REPO` as well.
   - Flux will commit its system manifests to your repository, so make sure you're using your own fork (see step 1).
   - If you don't set `GITHUB_USER`, you'll need to manually edit `clusters/demo/flux-system/gitrepository.yaml` and replace `YOUR_USERNAME` with your GitHub username before applying.

5. **Verify installation**:
   ```bash
   # Check cluster nodes
   kubectl get nodes
   
   # Check Flux components
   kubectl get pods -n flux-system
   flux get sources git
   
   # Check all pods across namespaces
   kubectl get pods -A
   ```

6. **Wait for applications to deploy**:
   ```bash
   # Watch pods until they're all running
   kubectl get pods -A -w
   ```
   Press `Ctrl+C` once all pods show `Running` status.

### Accessing the Platform

Once all services are running, you can access:

- **Kong API Gateway**: `http://localhost:8080`
- **Grafana Dashboard**: `kubectl port-forward -n monitoring svc/grafana 3000:3000` then visit `http://localhost:3000`
- **Management Portal**: `kubectl port-forward -n platform svc/management-portal 8081:80` then visit `http://localhost:8081`

### Testing the Demo

1. **Send a test event via API Gateway**:
   ```bash
   curl -X POST http://localhost:8080/api/v1/events \
     -H "Content-Type: application/json" \
     -d '{"type": "test", "data": "Hello from integration platform"}'
   ```

2. **Check event processing**:
   ```bash
   # View logs from HTTP Adapter
   kubectl logs -n platform -l app=http-adapter --tail=50
   
   # View logs from Transform Service
   kubectl logs -n platform -l app=transform-service --tail=50
   ```

### Cleanup

To remove the demo and free up resources:

```bash
# Delete the k3d cluster
k3d cluster delete integration-platform

# Or use the cleanup script (if available)
# ./scripts/cleanup.sh
```

### Troubleshooting

If you encounter issues:

1. **Cluster not starting**: Ensure Docker is running and has enough resources allocated
2. **Pods stuck in Pending**: Check node resources: `kubectl describe nodes`
3. **Flux not syncing**: Verify Git repository URL in `clusters/demo/flux-system/gitrepository.yaml`
4. **Port conflicts**: Modify ports in `scripts/setup-k3d.sh` if 8080 or 8443 are in use

For more detailed troubleshooting, see the `docs/` directory.

## Running on Azure Kubernetes Service (AKS)

This section provides instructions for deploying the demo on Azure Kubernetes Service (AKS).

### Prerequisites for AKS

In addition to the tools listed in the [Quick Start](#quick-start) section, you'll need:

1. **Azure CLI** (v2.40+)
   - Install: https://docs.microsoft.com/cli/azure/install-azure-cli
   - Verify: `az --version`

2. **Azure Account**
   - An active Azure subscription
   - Contributor or Owner role on the subscription
   - Verify: `az account show`

3. **Azure Container Registry (ACR)** (optional, for custom images)
   - Or use public container registries

### AKS Setup Steps

1. **Login to Azure**:
   ```bash
   az login
   az account set --subscription "YOUR_SUBSCRIPTION_ID"
   ```

2. **Set variables** (customize as needed):
   ```bash
   export RESOURCE_GROUP="integration-platform-rg"
   export AKS_CLUSTER_NAME="integration-platform-aks"
   export LOCATION="eastus"
   export NODE_COUNT=3
   export NODE_VM_SIZE="Standard_D4s_v3"
   ```

3. **Create resource group**:
   ```bash
   az group create \
     --name ${RESOURCE_GROUP} \
     --location ${LOCATION}
   ```

4. **Create AKS cluster**:
   ```bash
   az aks create \
     --resource-group ${RESOURCE_GROUP} \
     --name ${AKS_CLUSTER_NAME} \
     --node-count ${NODE_COUNT} \
     --node-vm-size ${NODE_VM_SIZE} \
     --enable-managed-identity \
     --network-plugin azure \
     --enable-addons monitoring \
     --generate-ssh-keys
   ```
   
   This will create an AKS cluster with:
   - 3 nodes (adjust `NODE_COUNT` as needed)
   - Standard_D4s_v3 VM size (4 vCPUs, 16GB RAM)
   - Azure CNI networking
   - Azure Monitor integration
   - Managed identity for authentication

5. **Get cluster credentials**:
   ```bash
   az aks get-credentials \
     --resource-group ${RESOURCE_GROUP} \
     --name ${AKS_CLUSTER_NAME} \
     --overwrite-existing
   ```

6. **Verify cluster connection**:
   ```bash
   kubectl get nodes
   kubectl cluster-info
   ```

7. **Bootstrap Flux**:
   ```bash
   export GITHUB_USER=your-github-username
   ./scripts/bootstrap-flux.sh
   ```
   
   **Important**: Make sure you've forked the repository to your own GitHub account (see step 1 in Quick Start), as Flux needs write access to commit Flux system manifests back to the repository during bootstrap.
   
   Note: If you're using a private Git repository, you may need to configure Flux with SSH keys or a personal access token.

8. **Wait for applications to deploy**:
   ```bash
   # Watch pods until they're all running
   kubectl get pods -A -w
   ```
   Press `Ctrl+C` once all pods show `Running` status.

### Accessing Services on AKS

Unlike the local k3d setup, services on AKS are accessed differently:

#### Option 1: Using LoadBalancer Services

1. **Expose Kong API Gateway**:
   ```bash
   kubectl expose service kong -n platform \
     --type=LoadBalancer \
     --name=kong-external \
     --port=80 \
     --target-port=8000
   ```

2. **Get the external IP**:
   ```bash
   kubectl get svc kong-external -n platform
   # Wait for EXTERNAL-IP to be assigned, then access via http://EXTERNAL-IP
   ```

#### Option 2: Using Ingress Controller

1. **Install NGINX Ingress Controller** (if not already installed):
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
   ```

2. **Wait for ingress controller to be ready**:
   ```bash
   kubectl wait --namespace ingress-nginx \
     --for=condition=ready pod \
     --selector=app.kubernetes.io/component=controller \
     --timeout=300s
   ```

3. **Get the ingress IP**:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   ```

4. **Create Ingress resources** for your services (example):
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: kong-ingress
     namespace: platform
   spec:
     ingressClassName: nginx
     rules:
     - host: api.yourdomain.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: kong
               port:
                 number: 8000
   ```

#### Option 3: Using Port Forwarding (for testing)

For quick testing, you can use port forwarding:

```bash
# Kong API Gateway
kubectl port-forward -n platform svc/kong 8080:8000

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Management Portal
kubectl port-forward -n platform svc/management-portal 8081:80
```

Then access services at:
- Kong: `http://localhost:8080`
- Grafana: `http://localhost:3000`
- Management Portal: `http://localhost:8081`

### AKS-Specific Configuration

1. **Configure Azure Container Registry (if using custom images)**:
   ```bash
   # Attach ACR to AKS
   az aks update \
     --resource-group ${RESOURCE_GROUP} \
     --name ${AKS_CLUSTER_NAME} \
     --attach-acr <ACR_NAME>
   ```

2. **Enable Azure Monitor** (already enabled in step 4):
   - View metrics in Azure Portal: Azure Monitor → Insights → AKS cluster

3. **Configure persistent storage**:
   - AKS uses Azure Disks or Azure Files for persistent volumes
   - Ensure your storage classes are configured correctly for PostgreSQL and Redis

### Testing the Demo on AKS

1. **Get the service endpoint** (using LoadBalancer or Ingress):
   ```bash
   # If using LoadBalancer
   EXTERNAL_IP=$(kubectl get svc kong-external -n platform -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   
   # If using Ingress
   EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   ```

2. **Send a test event**:
   ```bash
   curl -X POST http://${EXTERNAL_IP}/api/v1/events \
     -H "Content-Type: application/json" \
     -d '{"type": "test", "data": "Hello from AKS integration platform"}'
   ```

3. **Check logs**:
   ```bash
   kubectl logs -n platform -l app=http-adapter --tail=50
   kubectl logs -n platform -l app=transform-service --tail=50
   ```

### Cleanup AKS Resources

To remove all AKS resources and avoid ongoing charges:

```bash
# Delete the AKS cluster
az aks delete \
  --resource-group ${RESOURCE_GROUP} \
  --name ${AKS_CLUSTER_NAME} \
  --yes

# Delete the resource group (this removes all resources in the group)
az group delete \
  --name ${RESOURCE_GROUP} \
  --yes \
  --no-wait
```

**Warning**: This will permanently delete all resources in the resource group. Make sure you've backed up any important data.

### AKS Troubleshooting

1. **Nodes not ready**: Check node status: `kubectl describe nodes`
2. **Pods stuck in Pending**: Check resource quotas: `kubectl describe pod <pod-name> -n <namespace>`
3. **LoadBalancer IP not assigned**: Ensure you have sufficient quota for public IPs in your subscription
4. **Flux sync issues**: Verify network connectivity and Git repository access from the cluster
5. **Storage issues**: Check persistent volume claims: `kubectl get pvc -A`
6. **View cluster logs**: Use Azure Monitor or `kubectl logs` for pod-specific issues

### Cost Considerations

AKS charges for:
- **Control plane**: Free (first cluster) or ~$73/month per cluster
- **Node VMs**: Based on VM size and quantity (e.g., Standard_D4s_v3 ≈ $0.192/hour)
- **Load Balancer**: ~$0.025/hour for standard SKU
- **Managed Disks**: Based on size and type
- **Egress data**: Charges for data transfer out of Azure

**Estimated monthly cost** (3 nodes, Standard_D4s_v3, 24/7):
- Nodes: ~$415/month
- Load Balancer: ~$18/month
- Storage: ~$10-50/month (depending on usage)
- **Total**: ~$450-500/month (excluding data transfer)

Consider using Azure Spot VMs or smaller node sizes for cost savings in development environments.

## Repository Structure

```
.
├── clusters/          # Cluster-specific configurations
│   └── demo/         # Demo cluster manifests
├── apps/             # Application definitions
├── scripts/          # Setup and utility scripts
└── docs/             # Documentation
```

## Components

### Infrastructure
- Redpanda: Event streaming platform
- PostgreSQL: Relational database
- Redis: Caching and pub/sub

### Platform Services
- Kong: API Gateway
- HTTP Adapter: HTTP to event bridge
- Transform Service: Message transformation
- Router Service: Message routing

### Monitoring
- Prometheus: Metrics collection
- Grafana: Visualization
- Loki: Log aggregation

## Documentation

See the `docs/` directory for detailed documentation:
- Setup guide
- Architecture details
- Demo scenarios
- Troubleshooting

## License

MIT

