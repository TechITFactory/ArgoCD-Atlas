Helm Integration: Argo CD recognizes any directory containing a Chart.yaml as a Helm application. It renders the templates locally using helm template and applies the resulting YAML to Kubernetes.

Helm Parameters: Key-value pairs used to override default settings in the values.yaml file (e.g., changing image tags or replica counts) directly from the Argo CD manifest.

Value Files: Instead of inline parameters, you can point Argo CD to specific environment files (e.g., values-prod.yaml) to manage complex configurations.

Public vs. Custom Charts: The video distinguishes between "Vendor Charts" (from public repositories like Bitnami) and "Internal Charts" (stored in your own Git repository).

# --- 1. DEPLOY FROM PUBLIC HELM REPOSITORY (Bitnami Nginx) ---
# This uses the 'chart' and 'repoURL' fields to fetch from a registry [00:05:31]
cat <<EOF > nginx-public-helm.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-helm-demo
  namespace: argocd
spec:
  project: default
  source:
    chart: nginx
    repoURL: https://charts.bitnami.com/bitnami
    targetRevision: 15.4.2
    helm:
      parameters:
      - name: "image.tag"
        value: "latest"      # Overriding the tag via parameters [00:06:11]
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# --- 2. DEPLOY CUSTOM CHART FROM GIT (Guestbook) ---
# This uses 'path' to find the chart inside your Git repo [00:15:52]
cat <<EOF > custom-git-helm.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook-helm
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: helm-guestbook
    helm:
      parameters:
      - name: "replicaCount"
        value: "3"           # Scaling to 3 replicas as shown in the demo [00:18:44]
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# --- 3. APPLY & VERIFY ---
kubectl apply -f nginx-public-helm.yaml
kubectl apply -f custom-git-helm.yaml

# Manual sync if needed to observe the transition to 3 replicas [00:19:24]
argocd app sync guestbook-helm

# Verify the pods in the namespace
kubectl get pods -n guestbook

Operational Insight
While parameters are great for quick changes, maintaining a separate values.yaml for different environments (Dev, Stage, Prod) within your Git repo is the preferred method for managing large, complex applications to keep your Argo CD manifest readable and clean.