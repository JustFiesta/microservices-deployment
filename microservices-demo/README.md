# Online Boutique - Microservices Demo Application

This directory contains the **Online Boutique** application - a cloud-native microservices demo application originally developed by Google Cloud Platform. This project uses it to demonstrate complete DevOps automation on AWS.

## About Online Boutique

**Online Boutique** is a web-based e-commerce application where users can browse items, add them to cart, and purchase them. It showcases modern microservices architecture with polyglot services communicating via gRPC.

**Original Source**: [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)

---

## Architecture

**Online Boutique** consists of 12 microservices communicating over gRPC:

### Service Overview

| Service | Language | Purpose | DevOps Notes |
|---------|----------|---------|--------------|
| **frontend** | Go | HTTP server, web UI | Entry point, exposed via LoadBalancer |
| **cartservice** | C# (.NET) | Shopping cart management | Uses Redis for state |
| **productcatalogservice** | Go | Product catalog from JSON | Stateless, easy to scale |
| **currencyservice** | Node.js | Currency conversion | Highest QPS service, good for HPA testing |
| **paymentservice** | Node.js | Payment processing (mock) | External API simulation |
| **shippingservice** | Go | Shipping cost calculation | Business logic service |
| **emailservice** | Python | Order confirmation emails (mock) | Async notification pattern |
| **checkoutservice** | Go | Order orchestration | Coordinates multiple services |
| **recommendationservice** | Python | Product recommendations | ML/AI service simulation |
| **adservice** | Java | Contextual advertisements | Legacy JVM service example |
| **loadgenerator** | Python/Locust | Traffic simulation | Continuous realistic load |
| **redis-cart** | Redis | Cart state storage | External dependency management |

### Communication Flow

```txt
User > frontend (HTTP)
       |
       frontend > productcatalogservice (gRPC)
       frontend > cartservice > redis-cart (gRPC > Redis)
       frontend > recommendationservice (gRPC)
       frontend > adservice (gRPC)
       frontend > currencyservice (gRPC)
       frontend > checkoutservice (gRPC)
                  |
                  checkoutservice > paymentservice (gRPC)
                  checkoutservice > shippingservice (gRPC)
                  checkoutservice > emailservice (gRPC)
                  checkoutservice > cartservice (gRPC)
```

### Protocol Buffers

All service-to-service communication uses gRPC with Protocol Buffers. API definitions are in [`/protos`](/protos) directory.

---

## How This Project Uses Online Boutique

### CI/CD Integration

Each microservice is independently:

- **Built**: Per-service Docker image builds (see [`/src/*/Dockerfile`](/src))
- **Versioned**: Semantic versioning per service (`frontend-1.2.3`, `cartservice-2.1.0`)
- **Scanned**: Trivy security scanning weekly
- **Tagged**: Multi-tag strategy (`dev-1.2.3`, `dev`, `1.2.3-abc1234`)
- **Promoted**: Crane-based image promotion across environments

### Auto-Discovery

#### ECR services

ECR automatically discovers services (via TF) by scanning for Dockerfiles:

```hcl
# terraform/environments/global/ecr.tf
locals {
  service_dirs = fileset("microservices-demo/src", "*/Dockerfile")
  # Discovers: frontend, cartservice, productcatalogservice, etc.
}
```

Adding a new service:

1. Create directory in `/src/newservice`
2. Add `Dockerfile`
3. Terraform auto-creates ECR repository
4. CI workflow auto-builds on changes

#### CI service changes discovery

CI works only for changed services. It build each only on changes in folders that contain Dockerfile.

---

### Deployment

Services are deployed to Kubernetes using:

- **Helm Chart**: [`/helm/microservices-demo`](/helm/microservices-demo) - All in one
- **ArgoCD**: GitOps continuous delivery from this repository
- **Environment-Specific Values**: `/helm/values-dev.yaml`, `/helm/values-prod.yaml`

## Local Development

### Quick Start with Docker Compose

```bash
# Start all 12 services + Redis
docker-compose up -d

# View logs
docker-compose logs -f

# Access application
open http://localhost:8080

# Stop all services
docker-compose down
```

See [`/docker-compose.yaml`](/docker-compose.yaml) for complete local setup.

### Development Workflow

1. **Make changes** to service code in `/src/<service>`
2. **Test locally** with `docker-compose up --build <service>`
3. **Create PR** with changes
4. **CI builds** new image automatically
5. **Change image in Helm** to newly created one
6. **ArgoCD deploys** to dev environment

### Testing Individual Services

```bash
# Build single service
docker-compose build frontend

# Run with dependencies
docker-compose up frontend cartservice redis-cart

# Rebuild and restart
docker-compose up --build currencyservice
```

---

## Differences from Original GCP Version

This fork includes modifications for AWS deployment:

### Removed GCP-Specific Features

- GKE-specific configurations
- Google Cloud Operations integrations (Stackdriver, Cloud Trace)
- GCP-specific service mesh configurations
- ShopAssistant service wont work becouse there is no AlloyDB or Gemini invovled - app stays functional without it, but assitant fails to start

### Added Features

- Per-service semantic versioning
- Environment-based tagging strategy
- Terraform auto-discovery integration
- GitHub Actions CI/CD workflows
- ArgoCD GitOps deployment
- Helm package with default values

---

## Deployment Variations

The original repository supports multiple deployment variations. This project uses:

- **Base Deployment**: Standard Kubernetes manifests via Helm
- **ArgoCD GitOps**: Continuous delivery from Git
- **Monitoring**: Prometheus/Grafana stack
- **Ingress**: NGINX Ingress Controller

**Not used** (available in original repo):

- Istio/Service Mesh variations
- Google Cloud Spanner integration
- AI assistant with Gemini
- Kustomize variations

See [original repository](https://github.com/GoogleCloudPlatform/microservices-demo) for full list of deployment options.

## Reference Documentation

- **Original GCP Repository**: [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)
- **Architecture Details**: [Original Architecture Docs](https://github.com/GoogleCloudPlatform/microservices-demo#architecture)

## Project Integration

To understand how this application integrates with the complete DevOps pipeline:

- **Infrastructure**: See [`/terraform/README.md`](/terraform/README.md) - ECR, EKS setup
- **CI/CD Workflows**: See [`/.github/README.md`](/.github/README.md) - Build, promotion workflows
- **GitOps Deployment**: See [`/argocd/README.md`](/argocd/README.md) - ArgoCD configuration
- **Helm Charts**: See [`/helm/README.md`](/helm/README.md) - Kubernetes deployment manifests
