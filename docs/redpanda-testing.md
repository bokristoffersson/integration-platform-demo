# Redpanda Testing Guide

This guide covers testing and verification of the Redpanda cluster deployment.

## Prerequisites

- kubectl configured and connected to the cluster
- Redpanda cluster deployed and running
- `jq` installed (for JSON parsing in scripts)
- `curl` installed (for HTTP API testing)

## Test Scripts

### 1. Health Check Script

**Script:** `scripts/test-redpanda-health.sh`

Verifies the Redpanda cluster health and broker status.

```bash
# Basic usage
./scripts/test-redpanda-health.sh

# With custom namespace
REDPANDA_NAMESPACE=infrastructure ./scripts/test-redpanda-health.sh
```

**What it checks:**
- RedpandaCluster CR existence and status
- Pod status and readiness
- Service availability
- Broker endpoints
- Basic connectivity

### 2. HTTP API Test Script

**Script:** `scripts/test-redpanda-http.sh`

Tests the Redpanda HTTP REST API (PandaProxy) endpoints.

```bash
# Basic usage
./scripts/test-redpanda-http.sh

# With custom topic name
TEST_TOPIC=my-test-topic ./scripts/test-redpanda-http.sh
```

**What it tests:**
- Health endpoint (`/v1/status/ready`)
- Topic listing (`/v1/topics`)
- Topic creation (`POST /v1/topics/{topic}`)
- Message production (`POST /v1/topics/{topic}/records`)
- Message consumption (`GET /v1/topics/{topic}/records`)
- Topic metadata (`GET /v1/topics/{topic}`)

### 3. Produce/Consume Test Script

**Script:** `scripts/test-redpanda-produce-consume.sh`

Comprehensive test for producing and consuming messages via HTTP API.

```bash
# Basic usage (10 messages)
./scripts/test-redpanda-produce-consume.sh

# With custom message count
NUM_MESSAGES=50 ./scripts/test-redpanda-produce-consume.sh
```

**What it does:**
- Creates a test topic
- Produces multiple messages with structured data
- Consumes messages and verifies delivery
- Displays topic information

### 4. Comprehensive Test Suite

**Script:** `scripts/test-redpanda-suite.sh`

Runs all tests in sequence and provides a summary.

```bash
./scripts/test-redpanda-suite.sh
```

**Test sequence:**
1. Cluster health check
2. HTTP API basic test
3. Produce/consume test

## Redpanda Console (Management UI)

### Accessing the Console

**Script:** `scripts/access-redpanda-console.sh`

The Redpanda Console provides a web-based management interface for:
- Viewing topics and partitions
- Producing and consuming messages
- Monitoring cluster health
- Schema registry management
- User and ACL management

```bash
# Start port forward to console
./scripts/access-redpanda-console.sh

# Then open browser to: http://localhost:8080
```

### Console Configuration

The console is configured via the `Console` CRD in:
- `clusters/demo/infrastructure/redpanda/console.yaml`

**Features:**
- Connects to Redpanda brokers
- Accesses Admin API for cluster management
- Connects to Schema Registry
- Read/write mode enabled

### Manual Console Access

If the script doesn't work, you can manually port-forward:

```bash
# Get console service name
kubectl get svc -n infrastructure -l app.kubernetes.io/name=console

# Port forward
kubectl port-forward -n infrastructure svc/redpanda-console 8080:8080
```

## Redpanda HTTP REST API

The Redpanda cluster exposes a Kafka-compatible HTTP REST API via PandaProxy on port 8082.

### Endpoints

#### Health Check
```bash
curl http://localhost:8082/v1/status/ready
```

#### List Topics
```bash
curl http://localhost:8082/v1/topics
```

#### Create Topic
```bash
curl -X POST http://localhost:8082/v1/topics/my-topic \
  -H "Content-Type: application/json" \
  -d '{
    "topic_settings": {
      "partitions": 3,
      "replication_factor": 1
    }
  }'
```

#### Produce Message
```bash
curl -X POST http://localhost:8082/v1/topics/my-topic/records \
  -H "Content-Type: application/vnd.kafka.json.v2+json" \
  -d '{
    "records": [
      {
        "value": {"message": "Hello Redpanda"}
      }
    ]
  }'
```

#### Consume Messages
```bash
curl -X GET "http://localhost:8082/v1/topics/my-topic/records?max_bytes=1000&timeout=5000" \
  -H "Accept: application/vnd.kafka.json.v2+json"
```

### Port Forwarding for API Access

```bash
# Get service name
kubectl get svc -n infrastructure -l app.kubernetes.io/name=redpanda

# Port forward to PandaProxy
kubectl port-forward -n infrastructure svc/redpanda 8082:8082
```

## Using rpk CLI

You can also use the `rpk` CLI tool directly in Redpanda pods:

```bash
# Get a pod name
POD=$(kubectl get pods -n infrastructure -l app.kubernetes.io/name=redpanda -o jsonpath='{.items[0].metadata.name}')

# Execute rpk commands
kubectl exec -n infrastructure $POD -- rpk cluster info
kubectl exec -n infrastructure $POD -- rpk topic list
kubectl exec -n infrastructure $POD -- rpk topic create test-topic --partitions 3 --replicas 1
```

## Troubleshooting

### Cluster Not Ready

If the cluster health check fails:

1. Check pod status:
   ```bash
   kubectl get pods -n infrastructure -l app.kubernetes.io/name=redpanda
   ```

2. Check pod logs:
   ```bash
   kubectl logs -n infrastructure <pod-name>
   ```

3. Check RedpandaCluster status:
   ```bash
   kubectl get redpandacluster -n infrastructure -o yaml
   ```

### HTTP API Not Responding

1. Verify service exists:
   ```bash
   kubectl get svc -n infrastructure -l app.kubernetes.io/name=redpanda
   ```

2. Check if PandaProxy is enabled in cluster config
3. Verify port forwarding is working
4. Check pod logs for errors

### Console Not Accessible

1. Verify Console CR exists:
   ```bash
   kubectl get console -n infrastructure
   ```

2. Check console deployment:
   ```bash
   kubectl get deployment -n infrastructure -l app.kubernetes.io/name=console
   ```

3. Check console pod logs:
   ```bash
   kubectl logs -n infrastructure -l app.kubernetes.io/name=console
   ```

## Environment Variables

All test scripts support the following environment variables:

- `REDPANDA_NAMESPACE`: Namespace where Redpanda is deployed (default: `infrastructure`)
- `REDPANDA_CLUSTER_NAME`: Name of the RedpandaCluster CR (default: `redpanda`)
- `TEST_TOPIC`: Topic name for testing (default: auto-generated)
- `NUM_MESSAGES`: Number of messages for produce/consume tests (default: `10`)

## Next Steps

After verifying Redpanda is working:

1. Proceed to Phase 7: PostgreSQL setup
2. Configure platform services to use Redpanda
3. Set up monitoring for Redpanda metrics
4. Create sample integrations using Redpanda topics

