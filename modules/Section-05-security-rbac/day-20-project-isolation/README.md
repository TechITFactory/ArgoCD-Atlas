# Day 24 — Project Isolation

AppProject: The primary multi-tenancy primitive in Argo CD. It provides a logical grouping of applications and acts as a security boundary that restricts which Git repositories, destination clusters/namespaces, and Kubernetes resource kinds an application can use.

The Default Project: Every application belongs to a project. If unspecified, it belongs to the `default` project, which permits deployments from ANY repo to ANY cluster. This is dangerous in production and should be locked down immediately.

Source Restrictions: Projects can restrict which Git repositories are trusted sources. Negation patterns (prefixed with `!`) are supported to explicitly deny specific repos.

Destination Restrictions: Projects can restrict which clusters and namespaces an application may deploy to. This prevents teams from accidentally (or intentionally) deploying to the wrong environment.

Resource Whitelist/Blacklist: Projects can allow or deny specific Kubernetes resource kinds. For example, preventing a dev team from deploying `ClusterRoles` or `NetworkPolicies`.

# --- 1. CREATE A RESTRICTED PROJECT ---
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-frontend
  namespace: argocd
spec:
  description: "Restricted project for the frontend team"

  # Only allow deployments from specific repos
  sourceRepos:
  - "https://github.com/my-org/frontend-app.git"
  - "https://github.com/my-org/shared-configs.git"

  # Only allow deployments to specific namespaces
  destinations:
  - namespace: frontend-dev
    server: https://kubernetes.default.svc
  - namespace: frontend-staging
    server: https://kubernetes.default.svc

  # Only allow these namespaced resource types
  namespaceResourceWhitelist:
  - group: "apps"
    kind: Deployment
  - group: ""
    kind: Service
  - group: ""
    kind: ConfigMap
  - group: ""
    kind: Secret

  # Deny all cluster-scoped resources (no ClusterRoles, no CRDs)
  clusterResourceWhitelist: []

  # Enable orphaned resource monitoring
  orphanedResources:
    warn: true
```

# --- 2. LOCK DOWN THE DEFAULT PROJECT ---
# Prevent any application from using the wide-open default project
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: default
  namespace: argocd
spec:
  sourceRepos: []
  sourceNamespaces: []
  destinations: []
  namespaceResourceBlacklist:
  - group: "*"
    kind: "*"
```

# --- 3. ASSIGN APPLICATION TO A PROJECT ---
```bash
argocd app set guestbook --project team-frontend
```

# --- 4. CREATE PROJECT VIA CLI ---
```bash
argocd proj create team-frontend \
  -d https://kubernetes.default.svc,frontend-dev \
  -s https://github.com/my-org/frontend-app.git

# Add a destination
argocd proj add-destination team-frontend https://kubernetes.default.svc frontend-staging

# Verify
argocd proj get team-frontend
```

# --- 5. VERIFICATION ---
```bash
# List all projects
argocd proj list

# Try deploying to a namespace NOT allowed by the project
# This WILL fail with "application destination is not permitted"
argocd app create bad-app \
  --repo https://github.com/my-org/frontend-app.git \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace kube-system \
  --project team-frontend
# Expected: ERROR — destination not permitted
```

Operational Insight
In a multi-tenant Argo CD installation, the `default` project should be locked down to have zero permissions. Every team should receive a dedicated `AppProject` that whitelists only their specific repos, namespaces, and resource kinds. This is the foundation of "least privilege" in GitOps. Combined with RBAC policies from Day 23, this creates a layered security model: the Project controls WHAT can be deployed, while RBAC controls WHO can trigger the deployment.
