#!/bin/bash

set -euo pipefail

CLUSTER_NAME="integration-platform"
NODES=3

echo "🚀 Setting up k3d cluster: ${CLUSTER_NAME}"

# Check if cluster already exists
if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
    echo "⚠️  Cluster ${CLUSTER_NAME} already exists. Deleting..."
    k3d cluster delete "${CLUSTER_NAME}"
fi

# Create cluster with 3 nodes
echo "📦 Creating k3d cluster with ${NODES} nodes..."
k3d cluster create "${CLUSTER_NAME}" \
    --agents ${NODES} \
    --k3s-arg "--disable=traefik@server:0" \
    --port "8080:80@loadbalancer" \
    --port "8443:443@loadbalancer" \
    --wait

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Verify cluster
echo "✅ Verifying cluster setup..."
kubectl cluster-info
kubectl get nodes

# Check node status
echo ""
echo "📊 Node Status:"
kubectl get nodes -o wide

# Verify kubeconfig
if kubectl get nodes &>/dev/null; then
    echo ""
    echo "✅ Cluster ${CLUSTER_NAME} is ready!"
    echo ""
    echo "To use this cluster, run:"
    echo "  kubectl cluster-info"
    echo "  kubectl get nodes"
else
    echo "❌ Cluster verification failed!"
    exit 1
fi

