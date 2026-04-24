GitOps: An operational framework where the Git Repository is the "Source of Truth." All infrastructure and configuration are defined as code.

Argo CD Server (argocd-server): The API server that acts as the front door. it handles Web UI, CLI requests, and authentication.

Repo Server (argocd-repo-server): The service responsible for cloning Git repos and "translating" code (Helm/Kustomize) into raw Kubernetes manifests.

Application Controller: The "Brain" that manages the reconciliation loop. It constantly compares the Live State (Cluster) against the Desired State (Git).

Dex Server: An identity service for integrating external authentication providers like GitHub or LDAP.

Redis: A caching service used to speed up manifest generation and improve performance.

# --- 1. ARCHITECTURE INSPECTION ---
# List all Argo CD pods to verify the components discussed (Server, Repo, Controller, Dex, Redis)
kubectl get pods -n argocd

# Check the services to see the API endpoints
kubectl get svc -n argocd

# --- 2. TRACING THE SYNC (LOGS) ---
# Trace the Repo Server (cloning and manifest generation)
kubectl logs -l app.kubernetes.io/name=argocd-repo-server -n argocd --tail=50

# Trace the Application Controller (state comparison and reconciliation)
kubectl logs -l app.kubernetes.io/name=argocd-application-controller -n argocd --tail=50

# --- 3. APPLICATIONSET YAML ---
# The video introduces the ApplicationSet as an automation tool to generate apps [00:15:52]
cat <<EOF > argocd-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-appset
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: engineering-dev
        url: https://kubernetes.default.svc
      - cluster: engineering-prod
        url: https://kubernetes.default.svc
  template:
    metadata:
      name: '{{cluster}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{url}}'
        namespace: guestbook
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
EOF

# Command to apply the ApplicationSet discussed
# kubectl apply -f argocd-appset.yaml

# --- 4. VERIFYING THE PULL MODEL ---
# List applications to see the sync status managed by the controller
argocd app list

The "Pull Model" Workflow
CI Pipeline: Builds the image and updates the manifest in Git.

Argo CD: Continuously monitors Git.

Out of Sync: The Application Controller detects that the Cluster (Live State) does not match the Git (Desired State).

Sync: Argo CD "pulls" the new manifest and applies it to the cluster to reconcile the state.

--------------------------------------------------------------------------

Reconciliation Loop: The primary engine that ensures the cluster matches Git. It runs by default every 3 minutes to check for drift.

Desired State vs. Live State: The "Desired State" is what is defined in Git; the "Live State" is what is actually running in Kubernetes.

Leader Election: A mechanism for the Application Controller where, even if multiple replicas exist, only one "Leader" performs the reconciliation to prevent conflicting operations.

gRPC: The high-performance protocol used for all internal communication between Argo CD components (API Server, Repo Server, and Controller).

Sync Hooks: Specialized phases of a sync:

Pre-Sync: Runs before resources are applied (e.g., database migrations).

Post-Sync: Runs after success (e.g., sending Slack/Teams notifications).

# --- 1. TRACE THE RECONCILIATION LOOP ---
# Watch the Application Controller logs to see the "refresh" and "comparison" every 3 mins
kubectl logs -f -l app.kubernetes.io/name=argocd-application-controller -n argocd

# --- 2. TRACE MANIFEST GENERATION ---
# Watch the Repo Server logs in a separate terminal to see gRPC requests for new manifests
kubectl logs -f -l app.kubernetes.io/name=argocd-repo-server -n argocd

# --- 3. SYNC HOOK EXAMPLE (YAML) ---
# This is how you define a Pre-Sync Job to run before your main deployment
cat <<EOF > presync-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: schema-update-
  annotations:
    argocd.argoproj.io/hook: PreSync
spec:
  template:
    spec:
      containers:
      - name: config-checker
        image: alpine
        command: ["/bin/sh", "-c", "echo 'Checking prerequisites...'; sleep 5"]
      restartPolicy: Never
  backoffLimit: 1
EOF

# --- 4. HIGH AVAILABILITY (HA) COMMANDS ---
# Scaling components for HA (API and Repo servers can be multi-replica)
kubectl scale deployment argocd-server -n argocd --replicas=2
kubectl scale deployment argocd-repo-server -n argocd --replicas=2

# Note: The Application Controller uses Leader Election, so only 1 pod will be active.

The Sync Process Explained
Trigger: User or Webhook tells the API Server to sync.

Manifest Fetch: The Controller asks the Repo Server (via gRPC) for the YAMLs from Git.

Pre-Sync: Any resource with the PreSync annotation is executed first.

Sync: The main application resources (Deployments, Services) are applied.

Post-Sync: Notifications or cleanup jobs are triggered.