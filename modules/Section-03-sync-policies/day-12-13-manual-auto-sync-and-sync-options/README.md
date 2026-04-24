Sync (Synchronization): The process of reconciling the Desired State (Git) with the Live State (Cluster). If they do not match, the app is "OutOfSync".

Manual Sync: The default policy. Argo CD detects drift but requires a human to click "Sync" to apply changes.

Automated Sync: Argo CD automatically triggers a sync as soon as it detects a new commit in the Git repository.

Self-Heal: A subset of automated sync. If someone manually modifies the cluster (e.g., via kubectl), Argo CD will automatically revert those changes to match Git.

Prune: A setting that allows Argo CD to automatically delete resources in the cluster that have been removed from the Git repository.

# Sync Policies & Self-Healing
# --- 1. CREATE AN APPLICATION (MANUAL SYNC BY DEFAULT) ---
# This creates the pointer but won't deploy until you manually sync 
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# --- 2. MANUALLY TRIGGER THE FIRST SYNC ---
argocd app sync guestbook

# --- 3. CONFIGURE AUTOMATION (THE GITOPS WAY) ---
# Switch from Manual to Automated Sync 
argocd app set guestbook --sync-policy automated

# Enable Self-Heal to prevent manual cluster drift 
argocd app set guestbook --self-heal

# Enable Auto-Prune to clean up deleted resources 
argocd app set guestbook --auto-prune

# --- 4. THE RESULTING APPLICATION YAML ---
# This is how the 'spec.syncPolicy' looks after the commands above 
cat <<EOF > guestbook-sync-policy.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true      # Enabled via --auto-prune
      selfHeal: true   # Enabled via --self-heal
EOF

# --- 5. VERIFICATION ---
# Scale a deployment manually to watch Self-Heal revert it 
kubectl scale deployment guestbook-ui --replicas=5 -n default
# Watch the pods; they will immediately terminate back to the Git-defined count
kubectl get pods -n default -w


Why Self-Heal is Crucial
The instructor highlights that Automated Sync alone only handles "forward" updates (Git → Cluster). Without Self-Heal, the cluster can still drift if someone uses kubectl to make manual changes. Enabling Self-Heal ensures that Git remains the absolute authority over the cluster state at all times.