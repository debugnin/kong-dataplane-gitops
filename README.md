# Kong DataPlane GitOps

This repository contains ArgoCD applications for deploying Kong data planes for multiple customers using GitOps with mTLS authentication to Konnect control planes.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Konnect       │◄───│   Kong DataPlane │    │   ArgoCD        │
│   Control Plane │    │   (Customer)     │◄───│   GitOps        │
│                 │    │                  │    │                 │
│ • NAB CP        │    │ • kong-nab       │    │ • App-of-Apps   │
│ • CBA CP        │    │ • kong-cba       │    │ • Auto Sync     │
│ • ANZ CP        │    │ • kong-anz       │    │ • Self Heal     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         ▲                       │                       │
         │                       ▼                       ▼
         │              ┌──────────────────┐    ┌─────────────────┐
         │              │   Kubernetes     │    │   Redis         │
         │              │   TLS Secrets    │    │   (Dependency)  │
         │              │                  │    │                 │
         └──────────────│ • Client Certs   │    │ • Per Customer  │
            mTLS        │ • CA Certs       │    │ • Helm Charts   │
                        └──────────────────┘    └─────────────────┘
```

## Structure

```
kong-dataplane-gitops/
├── argocd/
│   ├── projects/
│   │   └── kong-dataplane-project.yaml        # ArgoCD project
│   └── applications/
│       ├── app-of-apps.yaml                   # Parent application
│       └── customers/                         # Customer applications
│           ├── nab.yaml                       # NAB Kong deployment
│           ├── cba.yaml                       # CBA Kong deployment
│           └── anz.yaml                       # ANZ Kong deployment
├── customers/
│   ├── base-values.yaml                       # Common Kong config
│   ├── nab-values.yaml                        # NAB-specific config
│   ├── cba-values.yaml                        # CBA-specific config
│   └── anz-values.yaml                        # ANZ-specific config
└── README.md
```

## Components

### Kong Data Planes
- **Multi-tenant**: Separate namespaces per customer (kong-nab, kong-cba, kong-anz)
- **mTLS Authentication**: Client certificates for secure Konnect communication
- **Redis Dependencies**: Dedicated Redis instances per customer
- **Observability**: Integrated with Prometheus, OpenTelemetry, and HTTP Log plugins

### ArgoCD GitOps
- **App-of-Apps Pattern**: Parent application manages customer applications
- **Automated Sync**: Continuous deployment from Git repository
- **Self-Healing**: Automatic drift correction
- **Multi-Environment**: Support for different customer configurations

### Redis Dependencies
- **Per-Customer**: Dedicated Redis instance for each customer
- **ArgoCD Managed**: Deployed as separate ArgoCD applications
- **Simple Deployment**: Basic Redis without clustering for development
- **Namespace Isolation**: Redis deployed in same namespace as Kong

### Certificate Management
- **Client Certificates**: Generated using OpenSSL with shared CA
- **Kubernetes Secrets**: TLS certificates stored as K8s secrets
- **Per-Customer**: Isolated certificate management per customer

## Deployment

### Prerequisites
- Kubernetes cluster with ArgoCD installed
- Konnect control planes created for each customer
- Client certificates generated and stored

### Certificate Generation

Generate client certificates for each customer:

```bash
# Generate CA (if not exists)
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -sha256 -subj "/C=AU/ST=NSW/O=Kong" -days 3650 -out ca.crt

# Generate client certificates for each customer
for customer in nab cba anz; do
  openssl genrsa -out ${customer}-client.key 2048
  openssl req -new -key ${customer}-client.key -out ${customer}-client.csr -subj "/CN=${customer}-client"
  openssl x509 -req -in ${customer}-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ${customer}-client.crt -days 3650
done
```

### Kubernetes Secrets

Create TLS secrets for each customer:

```bash
# Create namespaces
kubectl create namespace kong-nab
kubectl create namespace kong-cba  
kubectl create namespace kong-anz

# Create TLS secrets
for customer in nab cba anz; do
  kubectl create secret tls kong-${customer}-client-tls \
    --cert=${customer}-client.crt \
    --key=${customer}-client.key \
    -n kong-${customer}
done
```

### Redis Deployment

Redis is deployed as a dependency for each Kong data plane:

```bash
# Redis applications are automatically created by app-of-apps
# Each customer gets their own Redis instance:
# - redis-nab (in kong-nab namespace)
# - redis-cba (in kong-cba namespace) 
# - redis-anz (in kong-anz namespace)

# Verify Redis deployment
kubectl get pods -n kong-nab | grep redis
kubectl get pods -n kong-cba | grep redis
kubectl get pods -n kong-anz | grep redis
```

### ArgoCD Deployment

Deploy the Kong data planes via ArgoCD:

```bash
# Apply ArgoCD project
kubectl apply -f argocd/projects/kong-dataplane-project.yaml

# Deploy app-of-apps (will create all customer applications including Redis)
kubectl apply -f argocd/applications/app-of-apps.yaml

# Verify deployment
argocd app list | grep kong-dataplane
argocd app list | grep redis
```

## Configuration

### Base Configuration (base-values.yaml)
- **Common Settings**: Shared Kong configuration across all customers
- **Plugins**: Prometheus, OpenTelemetry, HTTP Log plugins enabled
- **Resources**: CPU/memory limits and requests
- **Security**: Pod security context and service account

### Customer-Specific Configuration
Each customer has dedicated values file with:
- **Control Plane Endpoint**: Unique Konnect CP URL
- **Certificates**: References to customer-specific TLS secrets
- **Namespace**: Isolated deployment namespace
- **Redis Configuration**: Connection to customer-specific Redis instance

### Redis Configuration
Each Kong data plane is configured to use its dedicated Redis:

```yaml
# In customer values files
env:
  database: "off"  # Use Redis instead of PostgreSQL
  
# Redis connection automatically configured via service discovery:
# redis-nab-master.kong-nab.svc.cluster.local:6379
# redis-cba-master.kong-cba.svc.cluster.local:6379
# redis-anz-master.kong-anz.svc.cluster.local:6379
```

### Example Customer Config (nab-values.yaml)
```yaml
env:
  cluster_control_plane: "https://your-cp-id.cp0.konghq.com"
  cluster_server_name: "your-cp-id.cp0.konghq.com"
  cluster_telemetry_endpoint: "https://your-cp-id.tp0.konghq.com"

certificates:
  cluster:
    enabled: true
    cert: kong-nab-client-tls
    key: kong-nab-client-tls
```

## Monitoring Integration

Kong data planes are configured with observability plugins:

### Prometheus Plugin
- **Metrics Endpoint**: `/metrics` on status port (8100)
- **Scraped by**: OpenTelemetry Collector in kong-observability namespace

### OpenTelemetry Plugin  
- **Traces**: Sent to OTel Collector via OTLP
- **Endpoint**: `http://otel-collector-opentelemetry-collector.kong-observability.svc.cluster.local:4318/v1/traces`

### HTTP Log Plugin
- **Logs**: Sent to Fluent Bit for processing
- **Endpoint**: `http://fluent-bit.kong-observability.svc.cluster.local:2020`
- **Correlation**: Includes trace/span IDs for correlation

## Access

### Kong Proxy Services
Each customer has a LoadBalancer service:

```bash
# Get service endpoints
kubectl get svc -n kong-nab kong-nab-dataplane-kong-proxy
kubectl get svc -n kong-cba kong-cba-dataplane-kong-proxy  
kubectl get svc -n kong-anz kong-anz-dataplane-kong-proxy

# Port forward for testing
kubectl port-forward -n kong-nab svc/kong-nab-dataplane-kong-proxy 8000:80
```

### Admin API (if enabled)
```bash
kubectl port-forward -n kong-nab svc/kong-nab-dataplane-kong-admin 8001:8001
```

## Troubleshooting

### Check ArgoCD Application Status
```bash
# List all applications
argocd app list

# Get application details
argocd app get kong-dataplane-nab

# Check sync status
kubectl describe application kong-dataplane-nab -n argocd
```

### Verify Kong Connectivity
```bash
# Check Kong logs
kubectl logs -n kong-nab deployment/kong-nab-dataplane-kong

# Check control plane connectivity
kubectl exec -n kong-nab deployment/kong-nab-dataplane-kong -- kong health

# Test proxy functionality
curl -i http://localhost:8000/
```

### Certificate Issues
```bash
# Verify TLS secret exists
kubectl get secret kong-nab-client-tls -n kong-nab

# Check certificate details
kubectl get secret kong-nab-client-tls -n kong-nab -o yaml

# Verify certificate validity
openssl x509 -in nab-client.crt -text -noout
```

### Redis Dependencies
```bash
# Check Redis pods
kubectl get pods -n kong-nab | grep redis
kubectl get pods -n kong-cba | grep redis
kubectl get pods -n kong-anz | grep redis

# Check Redis services
kubectl get svc -n kong-nab | grep redis
kubectl get svc -n kong-cba | grep redis
kubectl get svc -n kong-anz | grep redis

# Test Redis connectivity from Kong
kubectl exec -n kong-nab deployment/kong-nab-dataplane-kong -- redis-cli -h redis-nab-master ping
kubectl exec -n kong-cba deployment/kong-cba-dataplane-kong -- redis-cli -h redis-cba-master ping
kubectl exec -n kong-anz deployment/kong-anz-dataplane-kong -- redis-cli -h redis-anz-master ping

# Check Redis logs
kubectl logs -n kong-nab deployment/redis-nab-master
```

## Security

### mTLS Authentication
- **Client Certificates**: Unique per customer for Konnect authentication
- **CA Validation**: Konnect validates client certificates against configured CA
- **Certificate Rotation**: Certificates can be rotated via Kubernetes secrets

### Network Isolation
- **Namespaces**: Each customer isolated in separate namespace
- **Network Policies**: Can be applied for additional network segmentation
- **RBAC**: Service accounts with minimal required permissions

### Secret Management
- **Kubernetes Secrets**: TLS certificates stored as native K8s secrets
- **GitOps Safe**: No secrets stored in Git repository
- **Rotation**: Certificates can be updated without application restart

## Scaling

### Horizontal Scaling
```bash
# Scale Kong deployment
kubectl scale deployment kong-nab-dataplane-kong -n kong-nab --replicas=3
```

### Resource Management
- **Resource Limits**: Configured per customer in values files
- **HPA**: Horizontal Pod Autoscaler can be enabled
- **Node Affinity**: Can be configured for customer isolation

## Redis Management

### Redis Architecture
- **Simple Deployment**: Single Redis instance per customer (no clustering)
- **Persistence**: Data persisted to avoid data loss on pod restart
- **Resource Limits**: Configured for development workloads
- **Service Discovery**: Kong connects via Kubernetes service DNS

### Redis Scaling
```bash
# Scale Redis (if needed)
kubectl scale deployment redis-nab-master -n kong-nab --replicas=1

# Redis typically runs as single instance for development
# For production, consider Redis Sentinel or Cluster mode
```

### Redis Monitoring
- **Health Checks**: Built-in Redis health checks
- **Metrics**: Can be scraped by Prometheus if Redis exporter is enabled
- **Logs**: Available via kubectl logs

## Configuration Management

All configuration follows GitOps principles:
- **Version Control**: All changes tracked in Git
- **Pull Request Workflow**: Changes reviewed before deployment  
- **Automated Deployment**: ArgoCD handles deployment automation
- **Rollback**: Easy rollback via Git history or ArgoCD UI
- **Dependencies**: Redis automatically deployed with Kong data planes*: Easy rollback via Git history or ArgoCD UI