#!/bin/bash
# Test Redpanda cluster health and broker status

set -e

NAMESPACE="${REDPANDA_NAMESPACE:-infrastructure}"
CLUSTER_NAME="${REDPANDA_CLUSTER_NAME:-redpanda}"

echo "🔍 Checking Redpanda cluster health..."
echo "Namespace: $NAMESPACE"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "❌ Namespace '$NAMESPACE' not found"
    exit 1
fi

# Check if Cluster CR exists (using the correct resource type)
if ! kubectl get clusters.redpanda.vectorized.io "$CLUSTER_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "❌ Cluster '$CLUSTER_NAME' not found in namespace '$NAMESPACE'"
    echo "   Available clusters:"
    kubectl get clusters.redpanda.vectorized.io --all-namespaces 2>/dev/null || echo "   (none found)"
    exit 1
fi

echo "✅ Cluster CR found"
echo ""

# Get cluster status
echo "📊 Cluster Status:"
kubectl get clusters.redpanda.vectorized.io "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status}' | jq '.' 2>/dev/null || kubectl get clusters.redpanda.vectorized.io "$CLUSTER_NAME" -n "$NAMESPACE" -o yaml
echo ""

# Check pod status
echo "📦 Pod Status:"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=redpanda -o wide
echo ""

# Check if all pods are ready
READY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=redpanda --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
EXPECTED_REPLICAS=$(kubectl get clusters.redpanda.vectorized.io "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "3")

if [ "$READY_PODS" -ge "$EXPECTED_REPLICAS" ]; then
    echo "✅ All $EXPECTED_REPLICAS pods are running"
else
    echo "⚠️  Only $READY_PODS/$EXPECTED_REPLICAS pods are running"
    if [ "$READY_PODS" -eq 0 ]; then
        echo ""
        echo "💡 Troubleshooting:"
        echo "   1. Check if the Redpanda operator is running:"
        echo "      kubectl get pods -n redpanda-system"
        echo "   2. Check operator logs:"
        echo "      kubectl logs -n redpanda-system -l app.kubernetes.io/name=operator --tail=50"
        echo "   3. Check cluster events:"
        echo "      kubectl describe clusters.redpanda.vectorized.io $CLUSTER_NAME -n $NAMESPACE"
        echo "   4. Verify the operator is watching the correct resource type"
    fi
fi
echo ""

# Check services
echo "🌐 Services:"
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=redpanda
echo ""

# Get broker endpoints
echo "🔗 Broker Endpoints:"
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=redpanda -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.clusterIP}{":"}{.spec.ports[?(@.name=="kafka")].port}{"\n"}{end}'
echo ""

# Test connectivity to a broker pod
FIRST_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=redpanda -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$FIRST_POD" ]; then
    echo "🧪 Testing connectivity to pod: $FIRST_POD"
    if kubectl exec -n "$NAMESPACE" "$FIRST_POD" -- rpk cluster info &>/dev/null; then
        echo "✅ Cluster info accessible"
        kubectl exec -n "$NAMESPACE" "$FIRST_POD" -- rpk cluster info 2>/dev/null || echo "⚠️  rpk not available in pod, but pod is running"
    else
        echo "⚠️  Cannot execute rpk in pod (may need to wait for full initialization)"
    fi
fi

echo ""
echo "✅ Health check complete"

