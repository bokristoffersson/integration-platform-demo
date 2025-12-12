#!/bin/bash
# Test Redpanda HTTP endpoint (PandaProxy REST API)

set -e

NAMESPACE="${REDPANDA_NAMESPACE:-infrastructure}"
CLUSTER_NAME="${REDPANDA_CLUSTER_NAME:-redpanda}"
TOPIC_NAME="${TEST_TOPIC:-test-topic-$(date +%s)}"

echo "🧪 Testing Redpanda HTTP REST API (PandaProxy)"
echo "Namespace: $NAMESPACE"
echo "Cluster: $CLUSTER_NAME"
echo "Test Topic: $TOPIC_NAME"
echo ""

# Get the service name
SERVICE_NAME="${CLUSTER_NAME}"
if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    SERVICE_NAME="${CLUSTER_NAME}-panda-proxy"
fi

if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "❌ Could not find Redpanda service in namespace '$NAMESPACE'"
    echo "Available services:"
    kubectl get svc -n "$NAMESPACE"
    exit 1
fi

# Get service details
HTTP_PORT=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[?(@.name=="pandaproxy")].port}' 2>/dev/null || echo "8082")
SERVICE_HOST="${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"

echo "📡 Service: $SERVICE_NAME"
echo "🌐 Host: $SERVICE_HOST"
echo "🔌 Port: $HTTP_PORT"
echo ""

# Port forward in background
echo "🔌 Setting up port forward..."
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE_NAME" 8082:$HTTP_PORT > /dev/null 2>&1 &
PF_PID=$!
sleep 2

# Cleanup function
cleanup() {
    echo ""
    echo "🧹 Cleaning up port forward..."
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Test endpoints
BASE_URL="http://localhost:8082"

echo "📋 Testing REST API endpoints..."
echo ""

# 1. Health check
echo "1️⃣  Testing health endpoint..."
if curl -s -f "${BASE_URL}/v1/status/ready" > /dev/null; then
    echo "   ✅ Health check passed"
else
    echo "   ❌ Health check failed"
    exit 1
fi
echo ""

# 2. List topics (may be empty)
echo "2️⃣  Listing topics..."
TOPICS=$(curl -s "${BASE_URL}/v1/topics" 2>/dev/null || echo "[]")
echo "   Topics: $TOPICS"
echo ""

# 3. Create a topic
echo "3️⃣  Creating topic: $TOPIC_NAME"
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/topics/${TOPIC_NAME}" \
    -H "Content-Type: application/json" \
    -d '{"topic_settings": {"partitions": 1, "replication_factor": 1}}' 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "204" ]; then
    echo "   ✅ Topic created successfully"
else
    echo "   ⚠️  Topic creation response: HTTP $HTTP_CODE"
    echo "   Response: $(echo "$CREATE_RESPONSE" | head -n-1)"
fi
echo ""

# 4. Produce a message
echo "4️⃣  Producing test message..."
PRODUCE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/topics/${TOPIC_NAME}/records" \
    -H "Content-Type: application/vnd.kafka.json.v2+json" \
    -d '{
        "records": [
            {
                "value": {"test": "message", "timestamp": "'$(date -Iseconds)'"}
            }
        ]
    }' 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$PRODUCE_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Message produced successfully"
    echo "   Response: $(echo "$PRODUCE_RESPONSE" | head -n-1 | jq '.' 2>/dev/null || echo "$PRODUCE_RESPONSE")"
else
    echo "   ⚠️  Produce response: HTTP $HTTP_CODE"
    echo "   Response: $(echo "$PRODUCE_RESPONSE" | head -n-1)"
fi
echo ""

# 5. Consume messages
echo "5️⃣  Consuming messages..."
CONSUME_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/topics/${TOPIC_NAME}/records?max_bytes=1000&timeout=5000" \
    -H "Accept: application/vnd.kafka.json.v2+json" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$CONSUME_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Messages consumed successfully"
    echo "   Response: $(echo "$CONSUME_RESPONSE" | head -n-1 | jq '.' 2>/dev/null || echo "$CONSUME_RESPONSE")"
else
    echo "   ⚠️  Consume response: HTTP $HTTP_CODE"
    echo "   Response: $(echo "$CONSUME_RESPONSE" | head -n-1)"
fi
echo ""

# 6. Get topic metadata
echo "6️⃣  Getting topic metadata..."
METADATA_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/topics/${TOPIC_NAME}" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$METADATA_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Topic metadata retrieved"
    echo "   Response: $(echo "$METADATA_RESPONSE" | head -n-1 | jq '.' 2>/dev/null || echo "$METADATA_RESPONSE")"
else
    echo "   ⚠️  Metadata response: HTTP $HTTP_CODE"
fi
echo ""

echo "✅ HTTP API test complete"
echo ""
echo "💡 To test manually:"
echo "   kubectl port-forward -n $NAMESPACE svc/$SERVICE_NAME 8082:$HTTP_PORT"
echo "   curl http://localhost:8082/v1/topics"

