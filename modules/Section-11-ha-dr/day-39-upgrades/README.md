# Day 43 — Safe Upgrades and Maintenance

Argo CD releases minor versions frequently, often introducing powerful new features but also breaking changes to the Custom Resource Definitions (CRDs). Upgrading a production Argo CD instance requires a strict, methodical approach to avoid taking down your GitOps pipelines.

# --- 1. THE GOLDEN RULES OF UPGRADING ---
According to the official documentation, you must follow these rules:
1. **Never skip a minor version.** If you are on `v2.8` and want to reach `v2.10`, you must upgrade to `v2.9` first, verify stability, and then upgrade to `v2.10`.
2. **Read the Upgrading documentation.** Every minor release has a dedicated page in the official docs (e.g., `Upgrading v2.10 to v2.11`) listing breaking changes.
3. **Backup before upgrading.** Always run `argocd admin export > backup.yaml` before touching the cluster.

# --- 2. THE UPGRADE PROCEDURE ---

If you installed Argo CD using raw manifests, the upgrade process is a two-step `kubectl apply`. 

**Step 1: Upgrade the CRDs**
You must always upgrade the CRDs first. If you apply the manifests all at once, the new controller pods might start before the CRDs are updated, causing them to crash.
```bash
# Example: Upgrading to v2.10.0
# Add --server-side to avoid "Too long: must have at most 262144 bytes" errors
kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=v2.10.0 --server-side
```

**Step 2: Upgrade the Components**
Once the CRDs are updated, apply the new component manifests (HA version recommended for production).
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/ha/install.yaml
```

**Step 3: Verify the Rollout**
```bash
# Ensure all deployments and statefulsets successfully rolled over
kubectl -n argocd rollout status deploy/argocd-repo-server
kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd rollout status sts/argocd-application-controller
```

# --- 3. UPGRADING VIA HELM ---
If you installed Argo CD via the official Helm chart, the process is handled by updating the chart version.
```bash
helm repo update
# Always use --set installCRDs=true to ensure CRDs upgrade
helm upgrade argocd argo/argo-cd --namespace argocd --version 6.0.0 --set installCRDs=true
```

Operational Insight
The most common upgrade failure is the "Annotation too long" error when applying new CRDs. Kubernetes has an annotation size limit of 256KB, and Argo CD's CRDs have grown massive. You must use `kubectl apply --server-side` to bypass this client-side limitation. Additionally, always test your upgrade in a lower environment first. Argo CD is the heart of your platform; if you break it in production, nobody can deploy code.
