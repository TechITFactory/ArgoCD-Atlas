# Day 25 — ApplicationSet Theory

ApplicationSet: A Kubernetes CRD that automates the creation of multiple Argo CD `Application` resources from a single template. Instead of writing 10 separate Application YAML files for 10 microservices, you write one `ApplicationSet` and a Generator produces the 10 Applications automatically.

Generators: The engine of ApplicationSets. A generator produces a list of parameters (key-value pairs) and, for each set of parameters, an `Application` is created from the template. Argo CD supports: List, Cluster, Git (Directories & Files), Matrix, Merge, SCM Provider, Pull Request, and Plugin generators.

Template: The `Application` spec skeleton inside the ApplicationSet. Generators inject parameters into the template using `{{parameter}}` (or Go template syntax with `goTemplate: true`) to produce unique Application resources.

Parameter Substitution: Values from the generator are substituted into the template wherever `{{parameterName}}` appears. For example, `{{cluster.name}}` gets replaced with the actual cluster name for each generated Application.

# --- 1. BASIC APPLICATIONSET STRUCTURE ---
# One ApplicationSet = one template + one or more generators
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-appset
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - list:
      elements:
      - cluster: engineering-dev
        url: https://1.2.3.4
      - cluster: engineering-prod
        url: https://2.3.4.5
  template:
    metadata:
      name: '{{.cluster}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{.url}}'
        namespace: guestbook
```

This single ApplicationSet creates TWO Applications:
- `engineering-dev-guestbook` → deployed to `https://1.2.3.4`
- `engineering-prod-guestbook` → deployed to `https://2.3.4.5`

# --- 2. VERIFICATION ---
```bash
# Apply the ApplicationSet
kubectl apply -f appset.yaml

# Check generated Applications
argocd app list
```

Operational Insight
ApplicationSets solve the "Application sprawl" problem. In organizations with dozens of microservices deployed across multiple clusters and environments, manually maintaining individual Application YAML files becomes unmanageable. ApplicationSets let you define the pattern once, and the controller dynamically creates, updates, and deletes Applications as the generator inputs change. This is the foundation of scalable GitOps.
