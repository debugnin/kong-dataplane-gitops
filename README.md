# Kong DataPlane GitOps with mTLS

This guide walks you through setting up Kong data planes for multiple customers (NAB and CBA) using ArgoCD GitOps with mutual TLS authentication and HashiCorp Vault integration.

## Architecture Overview

The setup includes:
- **Konnect Control Planes**: Separate control planes for NAB and CBA customers
- **Kong Data Planes**: Deployed in `kong-nab` and `kong-cba` namespaces
- **ArgoCD**: GitOps deployment automation
- **HashiCorp Vault**: Certificate and secret management
- **mTLS**: Secure communication between data planes and control planes

## Prerequisites

- OpenSSL installed
- kubectl configured with access to your Kubernetes cluster
- ArgoCD installed
- HashiCorp Vault installed
- Konnect control planes created for NAB and CBA

## Step 1: Generate Client Certificates

Generate client certificates for NAB and CBA using the CA from konnect-terraform:

```bash
cd konnect-terraform/cert

# Generate NAB client certificate
openssl req -newkey rsa:2048 -nodes -keyout nab-client.key \
  -out nab-client.csr -subj "/CN=nab-client"
openssl x509 -req -in nab-client.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out nab-client.crt -days 3650

# Generate CBA client certificate
openssl req -newkey rsa:2048 -nodes -keyout cba-client.key \
  -out cba-client.csr -subj "/CN=cba-client"
openssl x509 -req -in cba-client.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out cba-client.crt -days 3650
```

## Step 2: Store Certificates in Vault

Store the certificates in HashiCorp Vault:

```bash
# Store NAB certificates
kubectl exec -it vault-0 -n vault -- vault kv put secret/tls/nab \
  cert="$(cat nab-client.crt)" \
  key="$(cat nab-client.key)"

# Store CBA certificates
kubectl exec -it vault-0 -n vault -- vault kv put secret/tls/cba \
  cert="$(cat cba-client.crt)" \
  key="$(cat cba-client.key)"

# Store CA certificate
kubectl exec -it vault-0 -n vault -- vault kv put secret/tls/ca \
  cert="$(cat ca.crt)"
```

## Step 3: Create Namespaces

Create dedicated namespaces for each customer:

```bash
kubectl create namespace kong-nab
kubectl create namespace kong-cba
```

## Step 4: Deploy ArgoCD Applications

Apply the ArgoCD project and applications:

```bash
# Apply project configuration
kubectl apply -f argocd/projects/kong-dataplane-project.yaml

# Apply applications
kubectl apply -f argocd/applications/customers/nab.yaml
kubectl apply -f argocd/applications/customers/cba.yaml

# Apply app-of-apps
kubectl apply -f argocd/applications/app-of-apps.yaml
```

## Step 5: Verify Deployment

Check the deployment status:

```bash
# Check ArgoCD applications
argocd app list

# Check Kong pods
kubectl get pods -n kong-nab
kubectl get pods -n kong-cba

# Check Kong connectivity to Konnect
kubectl logs -n kong-nab deployment/kong-nab-dataplane-kong
kubectl logs -n kong-cba deployment/kong-cba-dataplane-kong
```

## Configuration Files

### Customer Values
- `customers/base-values.yaml` - Common Kong configuration
- `customers/nab-values.yaml` - NAB-specific configuration
- `customers/cba-values.yaml` - CBA-specific configuration

### ArgoCD Applications
- `argocd/applications/customers/nab.yaml` - NAB deployment
- `argocd/applications/customers/cba.yaml` - CBA deployment
- `argocd/projects/kong-dataplane-project.yaml` - Project configuration

## Vault Integration

The Kong data planes use Vault references for certificates:

```yaml
env:
  cluster_cert: "{vault://hcv/secret/tls/nab/cert}"
  cluster_cert_key: "{vault://hcv/secret/tls/nab/key}"
```

## Troubleshooting

### Check Vault Connectivity
```bash
kong vault get {vault://hcv/secret/tls/nab/cert}
```

### Check ArgoCD Application Status
```bash
kubectl describe application kong-dataplane-nab -n argocd
```

### Check Kong Logs
```bash
kubectl logs -n kong-nab -l app=kong
```

## Security Notes

- All certificates are stored securely in HashiCorp Vault
- Each customer has isolated namespaces and certificates
- mTLS ensures secure communication with Konnect control planes
- ArgoCD provides GitOps-based deployment automation