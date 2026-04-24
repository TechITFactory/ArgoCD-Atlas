# Day 30 — Secrets Management in GitOps

Handling secrets (passwords, API keys, tokens) is the most common challenge when adopting GitOps. Because Git is the single source of truth, all configurations must be stored in Git. However, you cannot store plaintext Kubernetes `Secret` YAMLs in a repository. 

According to the official Argo CD documentation, there are two approaches to solving this problem: **Destination Cluster Secret Management** and **Manifest Generation-Based Secret Management**.

## 1. Destination Cluster Secret Management (Recommended)

In this approach, secrets are managed on the destination cluster itself. The manifests stored in Git contain either encrypted data or pointers to an external vault, but never the plaintext secret itself.

**Examples:**
- **Bitnami Sealed Secrets:** Encrypts the secret locally into a `SealedSecret` CRD. The operator in the cluster decrypts it.
- **External Secrets Operator (ESO):** Stores a pointer (`ExternalSecret` CRD) in Git. The operator fetches the real secret from AWS Secrets Manager, Azure KeyVault, or Hashicorp Vault and injects it into the cluster.
- **Secrets Store CSI Driver:** Mounts enterprise vault secrets directly into Pods as volumes.

**Why Argo CD strongly recommends this:**
- **Security:** Argo CD itself never has access to the plaintext secrets.
- **Decoupling:** Secret rotation happens independently of Argo CD app syncs.

## 2. Manifest Generation-Based Secret Management (Not Recommended)

In this approach, you use an Argo CD Config Management Plugin (like `argocd-vault-plugin`) to inject secrets during the manifest rendering phase. You put placeholders like `<path:vault/my-secret#key>` in your Git manifests, and Argo CD replaces them with real secrets before deploying.

**Why Argo CD cautions against this:**
- **Security:** Argo CD needs access to the vault. Generated manifests (with plaintext secrets) are stored in Argo CD's Redis cache, increasing the attack surface.
- **Coupling:** An unrelated deployment might trigger a secret update if the vault changed.
- **Incompatible with Rendered Manifests:** Breaks the best practice of storing fully rendered YAML in a dedicated branch.

## Next Steps
Over the next two days, we will implement the recommended approach using the two most popular tools in the industry:
1. **Bitnami Sealed Secrets** (Day 31)
2. **External Secrets Operator** (Day 32)
