# Day 32 — External Secrets Operator (ESO)

The [External Secrets Operator (ESO)](https://external-secrets.io/) is an enterprise-grade Kubernetes operator that implements "Destination Cluster Secret Management". Instead of encrypting secrets and storing them in Git (like Sealed Secrets), ESO integrates directly with external enterprise secret management systems like AWS Secrets Manager, HashiCorp Vault, Google Secret Manager, or Azure Key Vault.

How it works:
1. You store your actual plaintext secret in an external system (e.g., AWS Secrets Manager).
2. You define a `SecretStore` resource in Kubernetes that tells ESO how to authenticate to the external system.
3. You write an `ExternalSecret` resource that acts as a pointer (e.g., "fetch the secret named `prod-db-password` from AWS").
4. You commit the `ExternalSecret` and `SecretStore` to Git. Argo CD deploys them.
5. ESO reads the `ExternalSecret`, connects to the external API, fetches the data, and generates a native Kubernetes `Secret`.

# --- 1. INSTALLATION ---
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true
```

# --- 2. THE SECRETSTORE ---
The `SecretStore` configures the connection to your provider. This example uses AWS Secrets Manager.
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: my-app
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        # Assumes IRSA (IAM Roles for Service Accounts) is configured
        # Or you can point to a Secret containing AWS credentials
        jwt:
          serviceAccountRef:
            name: eso-service-account
```

# --- 3. THE EXTERNALSECRET ---
The `ExternalSecret` is the pointer. This file is 100% safe to commit to Git.
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: my-app
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-credentials-secret # Name of the Kubernetes Secret to create
    creationPolicy: Owner
  data:
  - secretKey: password # Key inside the Kubernetes Secret
    remoteRef:
      key: prod/db/credentials # Name of the secret in AWS Secrets Manager
      property: password # JSON property inside the AWS secret
```

# --- 4. VERIFICATION ---
```bash
# Apply via Argo CD or manually
kubectl apply -f secretstore.yaml
kubectl apply -f externalsecret.yaml

# Check the status of the ExternalSecret
kubectl get externalsecret db-credentials -n my-app
# Output should show STATUS=SecretSynced

# Verify the native Kubernetes secret was created
kubectl get secret db-credentials-secret -n my-app
```

Operational Insight
ESO is the industry standard for enterprise GitOps. Unlike Sealed Secrets, there is no risk of losing a master decryption key because the single source of truth for the secret data remains your cloud provider's enterprise vault. Additionally, the `refreshInterval` feature ensures that if a database admin rotates a password directly in AWS/HashiCorp, ESO will automatically detect the change and update the Kubernetes Secret without any Git commits or Argo CD syncs required.
