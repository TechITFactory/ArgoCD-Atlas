# 1. Create the ArgoCD Namespace
kubectl create namespace argocd

# 2. Install ArgoCD using the official manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Wait for pods to be ready (Optional but recommended)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# 4. Get the initial Admin password to login
argocd admin initial-password -n argocd

# 5. Port-forward the UI to access it at http://localhost:8080
# Note: Keep this running in a separate terminal or run in background
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# 6. Login via CLI (Username: admin, Password from step 4)
argocd login localhost:8080

# 7. Create the Sample Guestbook Application
# This points to the official ArgoProj example repo
argocd app create guestbook \
--repo https://github.com/argoproj/argocd-example-apps.git \
--path guestbook \
--dest-server https://kubernetes.default.svc \
--dest-namespace guestbook

# 8. Sync the application (Deploy it to the cluster)
argocd app sync guestbook

# --- MANUAL DRIFT TEST (Demonstrated in Video) ---

# 9. Manually scale the deployment (ArgoCD will detect this and revert it)
kubectl scale deployment guestbook-ui -n guestbook --replicas=3

# 10. Watch ArgoCD revert it back to 1 replica (Source of Truth)
kubectl get pods -n guestbook -w

# --- EQUIVALENT APPLICATION YAML ---
# You can also apply the app via YAML instead of the CLI (Step 7)
cat <<EOF > guestbook-app.yaml
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
    namespace: guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# kubectl apply -f guestbook-app.yaml