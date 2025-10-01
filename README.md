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

2. Add repository to ArgoCD:
```bash
argocd repo add https://github.com/debugnin/kong-dataplane-gitops
```

3. Sync app-of-apps to create customer Applications:
```bash
argocd app refresh kong-dataplane-apps --hard
argocd app sync kong-dataplane-apps
```

4. Add new customer:
```bash
./scripts/generate-customer.sh customer-d
```

## App-of-Apps Pattern

This repository uses the app-of-apps pattern where:
- `kong-dataplane-apps` (master) manages all customer Applications
- Customer Applications are defined in `argocd/applications/customers/`
- Adding/removing customers is done by committing YAML files to Git
- Each customer Application deploys Kong DataPlane to their namespace

## Customer Environments

Each customer gets:
- Dedicated namespace
- Isolated Kong DataPlane instance
- Custom configuration via Kustomize overlays