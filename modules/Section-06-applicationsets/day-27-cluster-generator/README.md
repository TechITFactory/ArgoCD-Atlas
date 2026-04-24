# Day 27 — Cluster Generator

Cluster Generator: Automatically discovers clusters registered in Argo CD and creates one Application per cluster. It reads from the Argo CD cluster Secret list (stored as Kubernetes Secrets with the label `argocd.argoproj.io/secret-type: cluster`).

Available Parameters: For each cluster, the generator provides `{{.name}}`, `{{.server}}`, and any labels/annotations attached to the cluster Secret. You can also add custom values using the `values` field.

Label Selector: You can filter which clusters get Applications by using `selector.matchLabels`. For example, only target clusters labeled `env: production`.

Local Cluster: The cluster where Argo CD is installed (`https://kubernetes.default.svc`) is not included by default in the Cluster Generator output unless you explicitly set `spec.generators[].clusters.selector` to match it or omit the selector entirely.

# --- 1. CLUSTER GENERATOR — ALL CLUSTERS ---
# Creates an Application for EVERY cluster registered in Argo CD
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-all
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - clusters: {}
  template:
    metadata:
      name: '{{.name}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{.server}}'
        namespace: guestbook
```

# --- 2. CLUSTER GENERATOR — LABEL SELECTOR ---
# Only targets clusters with the label env=staging
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-staging
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - clusters:
      selector:
        matchLabels:
          env: staging
  template:
    metadata:
      name: '{{.name}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{.server}}'
        namespace: guestbook
```

# --- 3. CLUSTER GENERATOR — CUSTOM VALUES ---
# Pass additional key-value pairs into the template
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-values
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - clusters:
      selector:
        matchLabels:
          env: production
      values:
        revision: release-1.0
  template:
    metadata:
      name: '{{.name}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: '{{.values.revision}}'
        path: guestbook
      destination:
        server: '{{.server}}'
        namespace: guestbook
```

# --- 4. ADD A CLUSTER WITH LABELS ---
```bash
# Register a cluster with labels
argocd cluster add my-staging-context --label env=staging

# Verify the label is set on the cluster Secret
kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster -o yaml | grep -A2 labels
```

# --- 5. VERIFICATION ---
```bash
kubectl apply -f appset.yaml
argocd appset list
argocd app list
```

Operational Insight
The Cluster Generator is the key to true multi-cluster GitOps. When a new cluster is registered in Argo CD (via `argocd cluster add`), Applications are automatically created for it—zero manual YAML changes required. Combined with label selectors, you can create tiered rollout patterns: deploy to `env=dev` clusters first, then `env=staging`, then `env=production`. This is the building block for Progressive Syncs (Day 28).
