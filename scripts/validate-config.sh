#!/bin/bash

set -e

echo "Validating Kong DataPlane GitOps configuration..."

# Check if required tools are installed
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed."; exit 1; }
command -v kustomize >/dev/null 2>&1 || { echo "kustomize is required but not installed."; exit 1; }

# Validate ArgoCD applications
echo "Validating ArgoCD applications..."
for app in argocd/applications/customers/*.yaml; do
    if [ -f "$app" ]; then
        kubectl apply --dry-run=client -f "$app" > /dev/null
        echo "✓ $(basename "$app")"
    fi
done

# Validate Kustomize overlays
echo "Validating Kustomize overlays..."
for overlay in environments/overlays/*/; do
    if [ -d "$overlay" ]; then
        customer=$(basename "$overlay")
        kustomize build "$overlay" > /dev/null
        echo "✓ $customer overlay"
    fi
done

echo "All configurations are valid!"