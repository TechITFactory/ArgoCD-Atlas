argocd-cm (ConfigMap): The main settings file. It controls global configurations like the server URL, UI themes, and custom banners.

argocd-rbac-cm (ConfigMap): Manages Role-Based Access Control. This file defines who can access what resources within the Argo CD platform.

argocd-cmd-params-cm (ConfigMap): Used for advanced tuning, such as modifying startup flags for the various Argo CD components.

argocd-secret (Secret): Stores sensitive data, including the admin password and repository credentials. CRITICAL: Do not push this file to Git.

Safe Patch Method: Using kubectl patch with a JSON file instead of kubectl edit to ensure changes are controlled and reversible.

# --- 1. BACKUP INTERNAL SETTINGS ---
# Always take a backup before modifying core ConfigMaps or Secrets
mkdir -p ./argocd-backups
kubectl get cm argocd-cm -n argocd -o yaml > ./argocd-backups/argocd-cm-bak.yaml
kubectl get cm argocd-rbac-cm -n argocd -o yaml > ./argocd-backups/argocd-rbac-cm-bak.yaml
kubectl get secret argocd-secret -n argocd -o yaml > ./argocd-backups/argocd-secret-bak.yaml

# --- 2. CREATE A UI BANNER PATCH (JSON) ---
# This adds a notification banner to the top of the Argo CD Dashboard
cat <<EOF > banner-patch.json
{
  "data": {
    "ui.bannercontent": "Tech IT Factory Day 06: Maintenance in Progress",
    "ui.bannerurl": "https://techitfactory.com"
  }
}
EOF

# --- 3. APPLY THE PATCH ---
# Use the merge type to update only the specific fields without overwriting the whole CM
kubectl patch cm argocd-cm -n argocd --type merge --patch-file banner-patch.json

# --- 4. RESTART SERVER (OPTIONAL) ---
# Force the server to pick up the new UI settings immediately
kubectl rollout restart deployment argocd-server -n argocd

# --- 5. ROLLBACK PATCH (CLEANUP) ---
# To remove the banner, patch the values back to null
cat <<EOF > rollback-patch.json
{
  "data": {
    "ui.bannercontent": null,
    "ui.bannerurl": null
  }
}
EOF

# kubectl patch cm argocd-cm -n argocd --type merge --patch-file rollback-patch.json


Summary of Operational Best Practices
The instructor emphasizes that while these components are standard Kubernetes objects, they should be treated with care. Use ConfigMaps for non-sensitive settings that can be version-controlled in Git, but always use a .gitignore or a vault solution for the argocd-secret to avoid security disasters.