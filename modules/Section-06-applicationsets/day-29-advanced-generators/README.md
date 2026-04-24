# Day 29 — Advanced Generators

While List, Git, and Cluster generators cover 90% of use cases, Argo CD provides several advanced generators for complex, dynamic, or enterprise-scale deployments.

Matrix Generator: Combines the outputs of two child generators by creating the Cartesian product of their parameters. For example, combining a Git generator (finding 5 microservices) with a Cluster generator (finding 3 clusters) yields 15 total Applications (deploying every app to every cluster).

Merge Generator: Similar to Matrix, but merges the parameters of two child generators based on matching keys, rather than creating a Cartesian product. Useful for overriding base parameters with environment-specific parameters.

Pull Request Generator: Integrates with SCM providers (GitHub, GitLab, Bitbucket) via their APIs. It polls for open Pull Requests against a specific repository and generates parameters for each PR. When the PR is merged or closed, the generated Application is automatically deleted. This is the ultimate tool for ephemeral preview environments.

SCM Provider Generator: Discovers repositories within an entire SCM Organization. Instead of hardcoding a single `repoURL`, this generator automatically finds every repository in your GitHub/GitLab org and creates Applications for them.

# --- 1. MATRIX GENERATOR (Deploy all apps to all clusters) ---
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: matrix-generator-example
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - matrix:
      generators:
      # Generator 1: Find all clusters labeled env=staging
      - clusters:
          selector:
            matchLabels:
              env: staging
      # Generator 2: Find all microservice directories in Git
      - git:
          repoURL: https://github.com/argoproj/argocd-example-apps.git
          revision: HEAD
          directories:
          - path: apps/*
  template:
    metadata:
      # Creates e.g., "staging-cluster-frontend"
      name: '{{.name}}-{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: '{{.path.path}}'
      destination:
        server: '{{.server}}'
        namespace: '{{.path.basename}}'
```

# --- 2. PULL REQUEST GENERATOR (Ephemeral Environments) ---
# Requires a Kubernetes Secret containing a GitHub Personal Access Token (PAT)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: pr-preview-environments
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - pullRequest:
      github:
        # The GitHub organization and repository
        owner: my-org
        repo: frontend-app
        # Secret reference for API authentication
        tokenRef:
          secretName: github-token
          key: token
      # Requeue the PR check every 5 minutes
      requeueAfterSeconds: 300
  template:
    metadata:
      # Generates a unique app name per PR: "frontend-pr-123"
      name: 'frontend-pr-{{.number}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/my-org/frontend-app.git
        # Deploys the exact commit hash of the PR branch
        targetRevision: '{{.head_sha}}'
        path: manifests/
      destination:
        server: https://kubernetes.default.svc
        # Creates a unique namespace per PR: "pr-123-env"
        namespace: 'pr-{{.number}}-env'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

Operational Insight
The Pull Request generator is a massive quality-of-life upgrade for development teams. Instead of sharing a single `staging` environment where code changes might conflict, every developer gets a dedicated, isolated deployment of the entire application stack every time they open a PR. Because ApplicationSets cleanly delete the `Application` when the PR is closed, you avoid zombie environments eating up cluster resources.
