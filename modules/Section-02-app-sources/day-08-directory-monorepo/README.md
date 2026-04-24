Monorepo: A single Git repository that contains the code and configuration for multiple, separate projects or microservices (e.g., apps/payments, apps/users).

Directory App: The simplest form of an Argo CD application that points to a specific folder in Git and deploys the raw YAML/JSON files found inside.

Recursive Sync (recurse: true): A setting that tells Argo CD to scan not just the root folder, but all sub-directories within the path for manifests.

ApplicationSet: A high-level controller used to automate the creation of many Argo CD Applications at once using "Generators".

Git Generator: A feature of ApplicationSets that watches a Git repository's folder structure and automatically generates a new Argo CD App whenever a new folder is added.

# --- 1. RECURSIVE DIRECTORY APP (YAML) ---
# Use this when one app has manifests spread across sub-folders
cat <<EOF > recursive-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monorepo-directory-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
    directory:
      recurse: true               # Scans all sub-folders [00:10:23]
      include: "{*.yaml,*.yml}"   # Only include YAML files [00:11:36]
      exclude: "test/*"           # Ignore the test directory [00:11:36]
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF

# --- 2. APPLICATIONSET FOR AUTOMATED ONBOARDING (YAML) ---
# This automatically creates a new Argo CD App for every folder under 'apps/' [00:15:45]
cat <<EOF > monorepo-automation-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-microservices
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/techitfactory/monorepo-demo.git
      revision: HEAD
      directories:
      - path: apps/* # The 'Generator' watching your folders
  template:
    metadata:
      name: '{{path.basename}}'   # Dynamically names the app based on folder name
    spec:
      project: default
      source:
        repoURL: https://github.com/techitfactory/monorepo-demo.git
        targetRevision: HEAD
        path: '{{path}}'          # Dynamically sets the source path
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
EOF

# --- 3. APPLY COMMANDS ---
kubectl apply -f recursive-app.yaml
kubectl apply -f monorepo-automation-appset.yaml

# --- 4. VERIFICATION ---
# Check if the ApplicationSet has generated the individual apps
argocd appset list
argocd app list


The Benefit of "Self-Service"
The video emphasizes that in a real-world production environment with 50+ microservices, manually creating apps is a "nightmare". By using an ApplicationSet, the platform team provides a self-service model: a developer simply pushes a new folder to the Monorepo, and Argo CD automatically detects it and creates the managed application without any manual intervention.