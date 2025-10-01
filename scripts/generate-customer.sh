#!/bin/bash

set -e

CUSTOMER_NAME=$1

if [ -z "$CUSTOMER_NAME" ]; then
    echo "Usage: $0 <customer-name>"
    exit 1
fi

echo "Generating configuration for customer: $CUSTOMER_NAME"

# Create customer overlay directory
mkdir -p "environments/overlays/$CUSTOMER_NAME"

# Create kustomization.yaml
cat > "environments/overlays/$CUSTOMER_NAME/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: $CUSTOMER_NAME

resources:
- ../../base
- namespace.yaml

helmCharts:
- name: kong
  repo: https://charts.konghq.com
  version: 2.38.0
  releaseName: kong-dataplane
  namespace: $CUSTOMER_NAME
  valuesFile: values.yaml
EOF

# Create namespace.yaml
cat > "environments/overlays/$CUSTOMER_NAME/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $CUSTOMER_NAME
  labels:
    customer: $CUSTOMER_NAME
    kong.konghq.com/dataplane: "true"
EOF

# Create values.yaml
cat > "environments/overlays/$CUSTOMER_NAME/values.yaml" << EOF
deployment:
  kong:
    enabled: true

image:
  repository: kong/kong-gateway
  tag: "3.6"

env:
  role: data_plane
  database: "off"
  cluster_control_plane: "control-plane.kong.svc.cluster.local:8005"
  cluster_cert: /etc/secrets/kong-cluster-cert/tls.crt
  cluster_cert_key: /etc/secrets/kong-cluster-cert/tls.key
  cluster_telemetry_endpoint: "control-plane.kong.svc.cluster.local:8006"
  proxy_listen: "0.0.0.0:8000, 0.0.0.0:8443 ssl"
  admin_listen: "off"
  status_listen: "0.0.0.0:8100"

secretVolumes:
- kong-cluster-cert

proxy:
  enabled: true
  type: LoadBalancer

admin:
  enabled: false

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
EOF

# Create ArgoCD application
cat > "argocd/applications/customers/$CUSTOMER_NAME.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kong-dataplane-$CUSTOMER_NAME
  namespace: argocd
spec:
  project: kong-dataplane
  source:
    repoURL: https://github.com/your-org/kong-dataplane-gitops
    targetRevision: HEAD
    path: environments/overlays/$CUSTOMER_NAME
  destination:
    server: https://kubernetes.default.svc
    namespace: $CUSTOMER_NAME
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

echo "Configuration generated for customer: $CUSTOMER_NAME"
echo "Files created:"
echo "  - environments/overlays/$CUSTOMER_NAME/"
echo "  - argocd/applications/customers/$CUSTOMER_NAME.yaml"
echo ""
echo "Next steps:"
echo "1. Commit and push changes to Git"
echo "2. ArgoCD will automatically deploy the new customer environment"