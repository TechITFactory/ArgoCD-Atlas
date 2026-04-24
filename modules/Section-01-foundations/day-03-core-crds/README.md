Application (CRD): A resource that acts as a "pointer." It defines what to deploy (source Git repo) and where to deploy it (destination cluster/namespace).

AppProject (CRD): A "fence" or "guardrail." It provides a logical container to restrict which repositories, clusters, and Kubernetes resource types (Kinds) a specific team can use.

Finalizers: A setting that enables "cascade delete." If set, deleting the Argo CD application will also automatically clean up all associated Kubernetes resources in the cluster.

Least Privilege: The security practice of creating dedicated projects instead of using the "default" project, which is considered risky for production because it has unrestricted permissions.

# --- 1. PREPARE THE TARGET ENVIRONMENT ---
# The video uses a dedicated namespace for the demo app
kubectl create namespace tif-demo

# --- 2. DEFINE THE APPPROJECT (The Guardrail) ---
# This restricts the team to one specific repo and one specific namespace
cat <<EOF > 01-app-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: tif-dev
  namespace: argocd
spec:
  description: "Restricted project for TIF demo"
  sourceRepos:
  - "https://github.com/techitfactory/argocd-example-apps.git"
  destinations:
  - namespace: tif-demo
    server: https://kubernetes.default.svc
  resourceWhitelist:
  - group: 'apps'
    kind: Deployment
  - group: ''
    kind: Service
EOF
kubectl apply -f 01-app-project.yaml

# --- 3. DEFINE THE APPLICATION (The Resource Pointer) ---
# This links the source code to the project and destination
cat <<EOF > 02-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: day5-demo
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: tif-dev
  source:
    repoURL: https://github.com/techitfactory/argocd-example-apps.git
    targetRevision: HEAD
    path: app-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: tif-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
kubectl apply -f 02-application.yaml

# --- 4. VERIFICATION & POLICY ENFORCEMENT ---
# List the newly created resources
argocd app list
argocd proj get tif-dev

# TO TEST POLICY VIOLATION (As demonstrated at 024:31):
# If you try to change the application destination namespace to 'default',
# Argo CD will throw a 'not permitted' error because the 'tif-dev' project 
# only allows the 'tif-demo' namespace.

The Role of Governance
The video highlights that an application is only valid if its source and destination are explicitly permitted by the assigned AppProject. This mechanism prevents "chaos" in shared clusters by ensuring teams cannot accidentally (or intentionally) deploy resources to the wrong environment.