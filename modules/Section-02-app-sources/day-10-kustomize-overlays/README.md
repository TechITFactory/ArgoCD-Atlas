Kustomize Integration: Argo CD natively recognizes any directory containing a `kustomization.yaml` file. It renders the manifests using Kustomize and applies the resulting YAML to Kubernetes without requiring external build tools.

Base: The standard, reusable, unmodified configuration files (e.g., Deployments, Services) that serve as the foundation for all environments.

Overlay: Environment-specific configurations (like `dev`, `staging`, or `prod`) that reference the base and apply specific patches (e.g., changing replica counts, image tags, or namespaces).

Inline Patches & Overrides: Argo CD allows you to override properties inline within the Application manifest using `kustomize.images`, `kustomize.patches`, or `kustomize.components`. This dynamically changes configuration during deployment without altering the source repository.

# --- 1. DEPLOY KUSTOMIZE OVERLAY WITH IMAGE OVERRIDE ---
# This points Argo CD to a Kustomize application and overrides the image inline
cat <<EOF > kustomize-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: kustomize-guestbook
    kustomize:
      images:
      - "gcr.io/heptio-images/ks-guestbook-demo:0.2"  # Dynamically overriding the image tag
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# --- 2. DEPLOY KUSTOMIZE APP WITH INLINE PATCHES ---
# This applies an inline JSON patch to change a container port dynamically
cat <<EOF > kustomize-inline-patch-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-inline-guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: kustomize-guestbook
    kustomize:
      patches:
      - target:
          kind: Deployment
          name: guestbook-ui
        patch: |-
          - op: replace
            path: /spec/template/spec/containers/0/ports/0/containerPort
            value: 443
  destination:
    server: https://kubernetes.default.svc
    namespace: test-guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# --- 3. APPLY & VERIFY ---
kubectl apply -f kustomize-app.yaml
kubectl apply -f kustomize-inline-patch-app.yaml

# Manually sync the application if automatic sync is disabled or delayed
argocd app sync kustomize-guestbook

# Verify the deployed resources and their overridden values
kubectl get pods -n guestbook
kubectl get pods -n test-guestbook

Operational Insight
Using Kustomize with Argo CD provides a clean, patch-based approach to configuration management. Instead of duplicating YAML files for every environment, you maintain a single base and environment-specific overlays. Furthermore, Argo CD's inline Kustomize parameters (like \`images\` or \`patches\`) allow for dynamic deployment-time tweaks without bloating your Git repository with minor changes.
