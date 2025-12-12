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

- Docker
- kubectl
- k3d (v5.0.0+)
- flux CLI (v2.0.0+)

### Setup Steps

1. **Create k3d cluster**:
   ```bash
   ./scripts/setup-k3d.sh
   ```

2. **Bootstrap Flux**:
   ```bash
   ./scripts/bootstrap-flux.sh
   ```

3. **Verify installation**:
   ```bash
   kubectl get pods -A
   flux get sources git
   ```

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

