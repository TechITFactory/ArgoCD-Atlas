# Day 31 — Bitnami Sealed Secrets

[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) by Bitnami is an open-source Kubernetes controller and client tool (`kubeseal`) that implements "Destination Cluster Secret Management". It uses asymmetric encryption (public/private key).

How it works:
1. The Sealed Secrets controller generates an RSA key pair on the Kubernetes cluster. The private key never leaves the cluster.
2. Developers use the `kubeseal` CLI and the public key to encrypt a local Kubernetes `Secret` into a `SealedSecret` custom resource.
3. The `SealedSecret` (which is safely encrypted) is committed to Git and deployed by Argo CD.
4. The controller detects the `SealedSecret`, decrypts it using the cluster's private key, and creates a standard Kubernetes `Secret` for your applications to consume.

# --- 1. INSTALLATION ---
```bash
# Install the Sealed Secrets controller on the cluster
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system --create-namespace

# Install the kubeseal CLI locally (Linux/macOS)
brew install kubeseal
```

# --- 2. ENCRYPTING A SECRET ---
Create a standard Secret locally (do NOT commit this file):
```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: my-app
type: Opaque
stringData:
  password: super-secret-password
```

Use `kubeseal` to encrypt it. The CLI automatically fetches the public key from the cluster:
```bash
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml
```

# --- 3. THE GENERATED SEALEDSECRET ---
The resulting `sealed-secret.yaml` will look like this. This file is safe to commit to Git:
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-credentials
  namespace: my-app
spec:
  encryptedData:
    password: AgBy3i4OJSWK+PiTySYZZA9vkA... # Encrypted string
  template:
    metadata:
      name: db-credentials
      namespace: my-app
```

# --- 4. DEPLOY WITH ARGO CD ---
Push `sealed-secret.yaml` to your Git repository. Create an Argo CD Application to sync it:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sealed-secrets-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: HEAD
    path: sealed-secrets-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

# --- 5. VERIFICATION ---
```bash
# Verify Argo CD deployed the SealedSecret
kubectl get sealedsecret db-credentials -n my-app

# Verify the controller decrypted it into a standard Secret
kubectl get secret db-credentials -n my-app -o jsonpath='{.data.password}' | base64 --decode
```

Operational Insight
Sealed Secrets is fantastic for small-to-medium teams because it has zero external dependencies (no AWS/GCP bills). However, it faces challenges at fleet scale: if you lose the controller's private key, all your SealedSecrets in Git become permanently unreadable. Backing up the controller's sealing key (`kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key`) is critical for disaster recovery.
