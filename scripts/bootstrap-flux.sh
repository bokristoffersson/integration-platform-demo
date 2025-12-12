#!/bin/bash

set -euo pipefail

CLUSTER_NAME="integration-platform"
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_REPO="${GITHUB_REPO:-integration-platform}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

echo "🚀 Bootstrapping Flux on cluster: ${CLUSTER_NAME}"

# Check if k3d cluster exists
if ! k3d cluster list | grep -q "${CLUSTER_NAME}"; then
    echo "❌ Cluster ${CLUSTER_NAME} not found. Please run ./scripts/setup-k3d.sh first"
    exit 1
fi

# Check if flux CLI is installed
if ! command -v flux &> /dev/null; then
    echo "❌ flux CLI not found. Please install it first:"
    echo "   curl -s https://fluxcd.io/install.sh | sudo bash"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Cannot access cluster. Please check your kubeconfig"
    exit 1
fi

# Create flux-system namespace if it doesn't exist
echo "📦 Creating flux-system namespace..."
kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

# Install Flux components
echo "📦 Installing Flux components..."
flux install \
    --components=source-controller,kustomize-controller,helm-controller,notification-controller \
    --namespace=flux-system

# Wait for Flux components to be ready
echo "⏳ Waiting for Flux components to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=source-controller \
    -n flux-system \
    --timeout=300s || true
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=kustomize-controller \
    -n flux-system \
    --timeout=300s || true
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=helm-controller \
    -n flux-system \
    --timeout=300s || true
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=notification-controller \
    -n flux-system \
    --timeout=300s || true

# Apply Flux component manifests
echo "📝 Applying Flux component manifests..."
kubectl apply -f clusters/demo/flux-system/gotk-components.yaml

# If GitHub credentials are provided, bootstrap with GitRepository
if [ -n "${GITHUB_USER}" ]; then
    echo "🔗 Bootstrapping with GitRepository..."
    flux bootstrap github \
        --owner="${GITHUB_USER}" \
        --repository="${GITHUB_REPO}" \
        --branch="${GITHUB_BRANCH}" \
        --path=clusters/demo \
        --personal
else
    echo "⚠️  GITHUB_USER not set. Skipping GitRepository bootstrap."
    echo "   To bootstrap with Git, set GITHUB_USER and run:"
    echo "   flux bootstrap github --owner=<user> --repository=${GITHUB_REPO} --path=clusters/demo"
    echo ""
    echo "📝 Applying GitRepository manually..."
    kubectl apply -f clusters/demo/flux-system/gitrepository.yaml
fi

# Verify Flux installation
echo ""
echo "✅ Verifying Flux installation..."
flux check

echo ""
echo "📊 Flux components status:"
kubectl get pods -n flux-system

echo ""
echo "✅ Flux bootstrap complete!"

