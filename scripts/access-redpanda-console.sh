#!/bin/bash
# Script to access Redpanda Console (management UI)

set -e

NAMESPACE="${REDPANDA_NAMESPACE:-infrastructure}"
CONSOLE_NAME="${REDPANDA_CONSOLE_NAME:-redpanda-console}"

echo "🌐 Accessing Redpanda Console"
echo "Namespace: $NAMESPACE"
echo "Console: $CONSOLE_NAME"
echo ""

# Check if Console CR exists
if ! kubectl get console "$CONSOLE_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "⚠️  Console CR '$CONSOLE_NAME' not found in namespace '$NAMESPACE'"
    echo "   Creating console..."
    exit 1
fi

# Get console deployment
CONSOLE_DEPLOYMENT="${CONSOLE_NAME}"
if ! kubectl get deployment "$CONSOLE_DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
    echo "⚠️  Console deployment not found. Waiting for it to be created..."
    echo "   This may take a few moments after the Console CR is created."
    exit 1
fi

# Check if console pods are running
echo "📦 Console Pod Status:"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=console -o wide
echo ""

# Get console service
CONSOLE_SERVICE="${CONSOLE_NAME}"
if ! kubectl get svc "$CONSOLE_SERVICE" -n "$NAMESPACE" &>/dev/null; then
    CONSOLE_SERVICE="${CONSOLE_NAME}-console"
fi

if ! kubectl get svc "$CONSOLE_SERVICE" -n "$NAMESPACE" &>/dev/null; then
    echo "⚠️  Console service not found"
    exit 1
fi

# Get service port
CONSOLE_PORT=$(kubectl get svc "$CONSOLE_SERVICE" -n "$NAMESPACE" -o jsonpath='{.spec.ports[?(@.name=="http")].port}' 2>/dev/null || \
               kubectl get svc "$CONSOLE_SERVICE" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || \
               echo "8080")

echo "🔗 Console Service: $CONSOLE_SERVICE"
echo "🔌 Port: $CONSOLE_PORT"
echo ""

# Setup port forward
echo "🔌 Setting up port forward to Redpanda Console..."
echo "   Access the console at: http://localhost:8080"
echo ""
echo "   Press Ctrl+C to stop the port forward"
echo ""

kubectl port-forward -n "$NAMESPACE" "svc/$CONSOLE_SERVICE" 8080:$CONSOLE_PORT

