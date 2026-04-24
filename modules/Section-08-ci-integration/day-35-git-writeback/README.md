# Day 35 — Git Write-Back (Closing the Loop)

By default, the Argo CD Image Updater uses the Argo CD API to override image tags. While convenient, this creates configuration drift: the image running in production (and shown in the Argo CD UI) is newer than the image tag stored in your Git repository. If your cluster crashes and you rebuild it from Git, you will deploy the old, outdated version.

To maintain true GitOps, the Image Updater must be configured for **Git Write-Back**. In this mode, when a new image is found in the registry, the Image Updater actually makes a commit to your Git repository with the new tag.

# --- 1. HOW IT WORKS ---
When Git Write-Back is enabled, the Image Updater creates a `.argocd-source-<app-name>.yaml` file in the same directory as your application's manifests. This file contains the Argo CD parameter overrides. 

Argo CD automatically reads this file during synchronization. This ensures that the new image tag is permanently recorded in Git history.

# --- 2. CONFIGURING GIT WRITE-BACK ---

To enable Git Write-Back, you must provide the Image Updater with Git credentials, and you must add specific annotations to your Application.

**Step 2a: Provide Git Credentials**
Create a Kubernetes Secret containing a GitHub Personal Access Token (PAT) or an SSH private key.
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-creds
  namespace: argocd
stringData:
  # Use username/password for HTTPS
  username: "github-bot"
  password: "<your-github-pat>"
```

**Step 2b: Annotate the Application**
Add the `write-back-method` and `write-back-target` annotations to the `Application`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  annotations:
    argocd-image-updater.argoproj.io/image-list: my-app=mycompany/guestbook
    argocd-image-updater.argoproj.io/my-app.update-strategy: semver
    
    # 1. Enable Git Write-Back
    argocd-image-updater.argoproj.io/write-back-method: git
    
    # 2. Tell the Image Updater where to find the Git credentials
    # Format: gitrepocreds:<secret-name>
    argocd-image-updater.argoproj.io/write-back-target: gitrepocreds:git-creds
spec:
  project: default
  source:
    repoURL: https://github.com/mycompany/guestbook-config.git
    targetRevision: HEAD
    path: kustomize-app
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
```

# --- 3. VERIFICATION ---
1. Push a new semantic version (e.g., `v2.1.0`) to your container registry.
2. Check the logs of the Image Updater pod:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater
   ```
3. Check your Git repository. You should see a commit authored by `argocd-image-updater` containing a new `.argocd-source-guestbook.yaml` file.
4. Verify Argo CD has synchronized the new image to the cluster.

Operational Insight
Git Write-Back is the ultimate setup for automated CI/CD. It gives you the speed and reliability of the Image Updater (no brittle CI scripts) while preserving the absolute integrity of Git as the single source of truth. The resulting Git commits also act as an automatic audit log—you can look at your repository history and see exactly when every image update was rolled out.
