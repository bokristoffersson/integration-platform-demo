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

# Update GitRepository URL if GITHUB_USER is provided
if [ -n "${GITHUB_USER}" ]; then
    echo "📝 Updating GitRepository URL with GITHUB_USER..."
    GIT_REPO_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
    sed -i "s|url: https://github.com/YOUR_USERNAME/.*|url: ${GIT_REPO_URL}|" clusters/demo/flux-system/gitrepository.yaml
    echo "✅ Updated GitRepository URL to: ${GIT_REPO_URL}"
fi

# If GitHub credentials are provided and not skipping bootstrap, bootstrap with GitRepository
if [ -n "${GITHUB_USER}" ] && [ -z "${SKIP_FLUX_BOOTSTRAP:-}" ]; then
    echo "🔗 Bootstrapping with GitRepository..."
    flux bootstrap github \
        --owner="${GITHUB_USER}" \
        --repository="${GITHUB_REPO}" \
        --branch="${GITHUB_BRANCH}" \
        --path=clusters/demo \
        --personal
    
    # Apply infrastructure Kustomization if it exists
    if [ -f "clusters/demo/flux-system/infrastructure-kustomization.yaml" ]; then
        echo "📝 Applying infrastructure Kustomization..."
        kubectl apply -f clusters/demo/flux-system/infrastructure-kustomization.yaml
    fi
else
    if [ -z "${GITHUB_USER:-}" ]; then
        echo "⚠️  GITHUB_USER not set."
        echo ""
        echo "   Option 1: Set GITHUB_USER and let Flux bootstrap automatically:"
        echo "     export GITHUB_USER=your-github-username"
        echo "     export GITHUB_REPO=integration-platform-demo  # optional, defaults to integration-platform"
        echo "     ./scripts/bootstrap-flux.sh"
        echo ""
        echo "   Option 2: Manually update GitRepository URL:"
        echo "     1. Edit clusters/demo/flux-system/gitrepository.yaml"
        echo "     2. Replace YOUR_USERNAME with your GitHub username"
        echo "     3. Replace integration-platform-demo with your repository name"
        echo "     4. Apply: kubectl apply -f clusters/demo/flux-system/gitrepository.yaml"
        echo ""
    else
        echo "📝 Skipping Flux bootstrap (SKIP_FLUX_BOOTSTRAP is set). Applying GitRepository manually..."
    fi
    echo ""
    echo "📝 Applying GitRepository..."
    if grep -q "YOUR_USERNAME" clusters/demo/flux-system/gitrepository.yaml; then
        echo "❌ GitRepository still contains placeholder URL. Please set GITHUB_USER or update manually."
        exit 1
    fi
    kubectl apply -f clusters/demo/flux-system/gitrepository.yaml
    
    # Apply infrastructure Kustomization if it exists
    if [ -f "clusters/demo/flux-system/infrastructure-kustomization.yaml" ]; then
        echo "📝 Applying infrastructure Kustomization..."
        kubectl apply -f clusters/demo/flux-system/infrastructure-kustomization.yaml
    fi
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

