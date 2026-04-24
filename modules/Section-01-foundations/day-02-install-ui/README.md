Project: A security and governance boundary. It acts as a "folder" that restricts which Git repositories can be used and which destination clusters/namespaces are allowed for deployment.

Application (CRD): The primary resource in Argo CD that links a specific Git source to a Kubernetes destination.

Health Status: Indicates the runtime state of Kubernetes resources (Healthy, Progressing, Degraded, or Suspended).

Sync Status: Indicates whether the current cluster state matches the "Source of Truth" in Git (Synced or OutOfSync).

Resource Tree: A visual map in the UI that traces the hierarchy from Application down to Pods and Services.

# --- 1. SETTINGS & INFRASTRUCTURE MANAGEMENT ---

# Add an external Kubernetes cluster to Argo CD management
argocd cluster add <CONTEXT_NAME>

# List all clusters currently connected to your Argo CD instance
argocd cluster list

# Add a private Git repository with credentials
argocd repo add https://github.com/your-org/private-repo.git --username <USER> --password <TOKEN>

# --- 2. TROUBLESHOOTING & APP ACTIONS ---

# Trigger a manual refresh to detect drift (Sync vs OutOfSync)
argocd app get guestbook --refresh

# Manually sync an app to fix "OutOfSync" and "Degraded" states
argocd app sync guestbook

# --- 3. APPLICATION DEFINITION (YAML) ---
# This is the "App" resource managed via the 'Applications' dashboard tab

cat <<EOF > dashboard-mastery-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default         # Linked to 'Projects' settings
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook        # The folder in Git containing YAMLs
  destination:
    server: https://kubernetes.default.svc
    namespace: default     # Target namespace in the cluster
  syncPolicy:
    automated:             # Can be toggled in the UI
      prune: true
      selfHeal: true
EOF

# kubectl apply -f dashboard-mastery-app.yaml

Summary of UI Troubleshooting
If an application is Degraded or OutOfSync, the video demonstrates three primary steps in the UI:

Events Tab: Check the Kubernetes event stream for errors like ImagePullBackOff.

Logs Tab: View real-time container logs directly from the browser.

Manifest Tab: Compare the "Desired" YAML from Git with the "Live" YAML in the cluster to find exactly where the drift occurred.