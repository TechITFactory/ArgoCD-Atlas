# Day 26 — List & Git Generators

List Generator: The simplest generator. You define a static list of key-value element maps directly in the ApplicationSet YAML. Each element in the list produces one Application. Best for a small, known set of targets (e.g., 3 clusters, 5 environments).

Git Generator — Directories: Scans a Git repository for directories matching a given pattern. Each matching directory becomes a set of parameters (e.g., `{{path}}`, `{{path.basename}}`). Perfect for monorepos where each subdirectory is a separate microservice.

Git Generator — Files: Scans a Git repository for JSON/YAML files matching a given pattern. The contents of each file are loaded as parameters. This allows you to store per-environment config files in Git and auto-generate Applications from them.

# --- 1. LIST GENERATOR ---
# Explicitly lists every target. Simple and predictable.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: list-example
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - list:
      elements:
      - env: dev
        namespace: app-dev
      - env: staging
        namespace: app-staging
      - env: prod
        namespace: app-prod
  template:
    metadata:
      name: 'myapp-{{.env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.namespace}}'
```

# --- 2. GIT GENERATOR — DIRECTORIES ---
# Auto-discovers apps from a monorepo directory structure.
# Repo structure:
#   apps/
#     ├── backend/
#     ├── frontend/
#     └── worker/
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: git-dirs-example
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - git:
      repoURL: https://github.com/argoproj/argocd-example-apps.git
      revision: HEAD
      directories:
      - path: apps/*
  template:
    metadata:
      name: '{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.path.basename}}'
```

# --- 3. GIT GENERATOR — FILES ---
# Reads config from JSON/YAML files inside Git.
# Repo structure:
#   config/
#     ├── dev.json    → {"cluster": {"name": "dev", "address": "https://1.2.3.4"}}
#     └── prod.json   → {"cluster": {"name": "prod", "address": "https://5.6.7.8"}}
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: git-files-example
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - git:
      repoURL: https://github.com/argoproj/argocd-example-apps.git
      revision: HEAD
      files:
      - path: "config/*.json"
  template:
    metadata:
      name: '{{.cluster.name}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{.cluster.address}}'
        namespace: guestbook
```

# --- 4. VERIFICATION ---
```bash
kubectl apply -f appset.yaml
argocd appset list
argocd app list
```

Operational Insight
The List generator is best when your targets are known and stable (e.g., 3 fixed environments). The Git Directory generator shines in monorepos—add a new folder, and an Application appears automatically. The Git File generator gives you maximum flexibility by letting each config file define its own unique parameters. Choose the generator that matches how your team organizes code and infrastructure.
