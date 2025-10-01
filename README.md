# Kong DataPlane GitOps

ArgoCD-based GitOps repository for deploying Kong DataPlane instances to Kubernetes with multi-customer environments using direct Helm deployment.

## Structure

- `argocd/` - ArgoCD application and project definitions
- `customers/` - Customer-specific Helm values files
- `scripts/` - Utility scripts for customer management

## Architecture

This repository uses:
- **Direct Helm deployment** from Kong's official chart repository
- **Multi-source Applications** to combine Helm chart with customer values
- **App-of-apps pattern** for declarative Application management
- **Kong chart version 2.52.0** from `https://charts.konghq.com`

## Quick Start

1. Deploy ArgoCD project and app-of-apps:
```bash
kubectl apply -f argocd/projects/kong-dataplane-project.yaml
kubectl apply -f argocd/applications/app-of-apps.yaml
```

2. Add repository to ArgoCD:
```bash
argocd repo add https://github.com/debugnin/kong-dataplane-gitops
```

3. Sync app-of-apps to create customer Applications:
```bash
argocd app sync kong-dataplane-apps
```

4. Add new customer:
```bash
./scripts/generate-customer.sh customer-d
```

5. Validate configuration:
```bash
./scripts/validate-config.sh
```

## App-of-Apps Pattern

This repository uses the app-of-apps pattern where:
- `kong-dataplane-apps` (master) manages all customer Applications
- Customer Applications are defined in `argocd/applications/customers/`
- Adding/removing customers is done by committing YAML files to Git
- Each customer Application deploys Kong DataPlane to their namespace

## Customer Environments

Each customer gets:
- Dedicated namespace (auto-created)
- Isolated Kong DataPlane instance
- Custom configuration via Helm values files in `customers/`
- Direct deployment from Kong's official Helm chart

## Multi-Source Configuration

Each customer Application uses two sources:
1. **Kong Helm Chart**: `https://charts.konghq.com` (chart: kong, version: 2.52.0)
2. **Customer Values**: This repository's `customers/` directory

This approach eliminates the need for Kustomize overlays while maintaining customer-specific configurations.