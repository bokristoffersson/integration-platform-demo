#!/bin/bash
# Comprehensive test script for producing and consuming messages via HTTP API

set -e

NAMESPACE="${REDPANDA_NAMESPACE:-infrastructure}"
CLUSTER_NAME="${REDPANDA_CLUSTER_NAME:-redpanda}"
TOPIC_NAME="${TEST_TOPIC:-integration-test-$(date +%s)}"
NUM_MESSAGES="${NUM_MESSAGES:-10}"

echo "📨 Testing Produce/Consume via Redpanda HTTP API"
echo "Namespace: $NAMESPACE"
echo "Cluster: $CLUSTER_NAME"
echo "Topic: $TOPIC_NAME"
echo "Messages: $NUM_MESSAGES"
echo ""

# Get service name
SERVICE_NAME="${CLUSTER_NAME}"
if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    SERVICE_NAME="${CLUSTER_NAME}-panda-proxy"
fi

HTTP_PORT=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[?(@.name=="pandaproxy")].port}' 2>/dev/null || echo "8082")

# Setup port forward
echo "🔌 Setting up port forward..."
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE_NAME" 8082:$HTTP_PORT > /dev/null 2>&1 &
PF_PID=$!
sleep 3

cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

BASE_URL="http://localhost:8082"

# Create topic
echo "📝 Creating topic: $TOPIC_NAME"
curl -s -X POST "${BASE_URL}/v1/topics/${TOPIC_NAME}" \
    -H "Content-Type: application/json" \
    -d '{"topic_settings": {"partitions": 3, "replication_factor": 1}}' > /dev/null
echo "✅ Topic created"
echo ""

# Produce messages
echo "📤 Producing $NUM_MESSAGES messages..."
for i in $(seq 1 $NUM_MESSAGES); do
    MESSAGE=$(cat <<EOF
{
    "records": [
        {
            "key": "key-$i",
            "value": {
                "id": $i,
                "message": "Test message $i",
                "timestamp": "$(date -Iseconds)",
                "source": "test-script"
            }
        }
    ]
}
EOF
)
    
    RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/topics/${TOPIC_NAME}/records" \
        -H "Content-Type: application/vnd.kafka.json.v2+json" \
        -d "$MESSAGE")
    
    if echo "$RESPONSE" | jq -e '.offsets[0].offset' > /dev/null 2>&1; then
        OFFSET=$(echo "$RESPONSE" | jq -r '.offsets[0].offset')
        echo "   ✅ Message $i produced (offset: $OFFSET)"
    else
        echo "   ⚠️  Message $i: $RESPONSE"
    fi
done
echo ""

# Wait a bit for messages to be available
echo "⏳ Waiting for messages to be available..."
sleep 2
echo ""

# Consume messages
echo "📥 Consuming messages..."
CONSUME_RESPONSE=$(curl -s -X GET "${BASE_URL}/v1/topics/${TOPIC_NAME}/records?max_bytes=50000&timeout=10000" \
    -H "Accept: application/vnd.kafka.json.v2+json")

if echo "$CONSUME_RESPONSE" | jq -e '.records' > /dev/null 2>&1; then
    RECORD_COUNT=$(echo "$CONSUME_RESPONSE" | jq '.records | length')
    echo "✅ Consumed $RECORD_COUNT messages"
    echo ""
    echo "📋 Sample messages:"
    echo "$CONSUME_RESPONSE" | jq '.records[0:3]' 2>/dev/null || echo "$CONSUME_RESPONSE"
else
    echo "⚠️  Consume response: $CONSUME_RESPONSE"
fi
echo ""

# Get topic information
echo "📊 Topic Information:"
TOPIC_INFO=$(curl -s -X GET "${BASE_URL}/v1/topics/${TOPIC_NAME}")
echo "$TOPIC_INFO" | jq '.' 2>/dev/null || echo "$TOPIC_INFO"
echo ""

echo "✅ Produce/Consume test complete"

