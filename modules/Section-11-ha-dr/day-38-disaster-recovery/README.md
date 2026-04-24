# Day 42 — Disaster Recovery & Backups

Because Argo CD follows GitOps principles, the vast majority of your system state (Applications, Projects, manifests) is already safely stored in Git. If your cluster crashes, you don't lose your application configurations.

However, Argo CD holds some state *outside* of Git:
1. **Cluster Secrets:** The credentials required to authenticate to external Kubernetes clusters.
2. **Repository Secrets:** The SSH keys, GitHub PATs, or TLS certificates required to clone private Git repositories.
3. **SSO/OIDC Configuration:** Client IDs and Secrets for Dex.
4. **Local Users & RBAC:** Passwords for local admin accounts and Casbin policies.

If you lose the cluster running Argo CD, you will lose these credentials, and Argo CD will be unable to reconnect to your fleet.

# --- 1. THE IMPERATIVE BACKUP (`argocd admin export`) ---
The Argo CD CLI provides a built-in export command. It extracts all Secrets, ConfigMaps, Applications, and AppProjects into a single, portable YAML file.

```bash
# Run the export command
argocd admin export > argocd-backup.yaml

# To restore to a fresh cluster:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
argocd admin import - - < argocd-backup.yaml
```

**Warning:** The `argocd-backup.yaml` file contains plaintext secrets. You must store this file securely (e.g., in AWS S3 with KMS encryption, or HashiCorp Vault).

# --- 2. THE DECLARATIVE BACKUP (GitOps for GitOps) ---
The recommended approach for Disaster Recovery is the "App-of-Apps" or "AppSets" pattern applied to Argo CD itself.

Instead of running imperative CLI backups, you should:
1. Define your Argo CD configuration (ConfigMaps for RBAC, SSO, UI settings) as Kubernetes manifests in a Git repository.
2. Use a secrets management tool (like External Secrets Operator) to manage your cluster credentials and Git credentials in Git.
3. Create an Argo CD `Application` that deploys Argo CD's own configuration.

In a disaster scenario, you spin up a new cluster, install vanilla Argo CD, and apply this single "bootstrap" Application. Argo CD will reach into Git, pull down all its own ConfigMaps and ExternalSecrets, and fully restore itself without needing a manual backup file.

Operational Insight
The `argocd admin export` tool is useful for quick migrations or one-off backups before a major version upgrade, but it is an anti-pattern for long-term DR. The ultimate goal of a platform engineer is to manage the Argo CD installation *using Argo CD*. If you achieve "GitOps for GitOps", disaster recovery simply becomes: "Install Argo CD, apply one YAML file, and go get coffee while the platform rebuilds itself."
