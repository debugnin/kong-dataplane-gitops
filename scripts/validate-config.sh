#!/bin/bash

set -e

echo "Validating Kong DataPlane GitOps configuration..."

# Check if required tools are installed
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed."; exit 1; }

# Validate ArgoCD applications
echo "Validating ArgoCD applications..."
for app in argocd/applications/customers/*.yaml; do
    if [ -f "$app" ]; then
        kubectl apply --dry-run=client -f "$app" > /dev/null
        echo "✓ $(basename "$app")"
    fi
done

# Validate customer values files
echo "Validating customer values files..."
for values in customers/*-values.yaml; do
    if [ -f "$values" ]; then
        customer=$(basename "$values" -values.yaml)
        helm template kong-dataplane kong/kong --version 2.52.0 -f "$values" > /dev/null
        echo "✓ $customer values"
    fi
done

echo "All configurations are valid!"