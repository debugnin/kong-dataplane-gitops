# Kong DataPlane GitOps

ArgoCD-based GitOps repository for deploying Kong DataPlane instances to Kubernetes with multi-customer environments.

## Structure

- `argocd/` - ArgoCD application definitions
- `environments/` - Kustomize base and overlays for customer environments
- `helm/` - Custom Helm chart for Kong DataPlane
- `scripts/` - Utility scripts for customer management

## Quick Start

1. Deploy ArgoCD project and app-of-apps:
```bash
kubectl apply -f argocd/projects/kong-dataplane-project.yaml
kubectl apply -f argocd/applications/app-of-apps.yaml
```

2. Add new customer:
```bash
./scripts/generate-customer.sh customer-d
```

## Customer Environments

Each customer gets:
- Dedicated namespace
- Isolated Kong DataPlane instance
- Custom configuration via Kustomize overlays