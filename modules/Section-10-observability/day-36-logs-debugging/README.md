# Day 40 — Logs & Component Debugging

When metrics spike and the Grafana dashboard turns red, you must jump into the logs to find the root cause. Because Argo CD is a microservices architecture, you must know *which* component's logs to read based on the symptom.

# --- 1. THE ARGO CD COMPONENTS ---

**1. `argocd-application-controller`**
- **What it does:** Continuously compares live state in the cluster against the target state (manifests) provided by the repo-server.
- **Check these logs if:** Applications are stuck in `Progressing`, resources are failing to prune, or the sync process hangs.
- **Command:** `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`

**2. `argocd-repo-server`**
- **What it does:** Clones Git repositories and executes rendering tools (`helm template`, `kustomize build`).
- **Check these logs if:** Applications cannot find the Git repo, Helm values are missing, or you see `rpc error: code = Unknown desc = ` (which means the rendering tool crashed).
- **Command:** `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server`

**3. `argocd-server` (API/UI)**
- **What it does:** Serves the Web UI and handles CLI requests.
- **Check these logs if:** You cannot log in via SSO, the UI is crashing, or Webhooks from GitHub are failing to trigger syncs.
- **Command:** `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`

**4. `argocd-dex-server`**
- **What it does:** Identity broker for SSO integration.
- **Check these logs if:** Your OIDC/SAML integration is failing (e.g., Auth0, Okta, Azure AD).

# --- 2. ENABLING DEBUG LOGGING ---
If standard logs are not providing enough detail, you can enable `debug` logging on a per-component basis.

To enable debug logs for the application controller, edit its Deployment and append `--loglevel debug` to the container command args:

```yaml
# Alternatively, you can edit the argocd-cmd-params-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  # Set log level for the controller
  controller.log.level: "debug"
  # Set log level for the repo server
  reposerver.log.level: "debug"
```

Restart the deployments to pick up the new ConfigMap values:
```bash
kubectl rollout restart deploy argocd-repo-server -n argocd
kubectl rollout restart sts argocd-application-controller -n argocd
```

Operational Insight
The most common mistake engineers make is reading the `argocd-server` logs when a deployment fails. The API server only handles UI requests; it does not deploy code. If your YAML is invalid, read the `repo-server` logs. If your YAML is valid but Kubernetes refuses to apply it (e.g., webhook validation failed), read the `application-controller` logs.
