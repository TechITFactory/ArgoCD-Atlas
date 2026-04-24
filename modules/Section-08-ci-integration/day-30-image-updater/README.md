# Day 34 — Argo CD Image Updater

The [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/) is an official extension for Argo CD that can automatically update the container images of Kubernetes workloads managed by Argo CD.

Instead of writing custom bash scripts in your CI pipeline to push commits back to Git (as seen in Day 33), the Image Updater reverses the flow: it actively polls your container registry (e.g., Docker Hub, ECR) for new tags. When it finds a new image that matches your defined update strategy, it automatically tells Argo CD to deploy it.

# --- 1. UPDATE STRATEGIES ---
You configure the Image Updater by adding annotations to your Argo CD `Application` resource. The most critical annotation is the update strategy:

- **`semver`** (Default): Updates to the highest allowed semantic version (e.g., if configured for `~1.2`, it updates to `1.2.3` but ignores `1.3.0`).
- **`latest`**: Updates to the most recently built image tag based on the registry's build timestamp. (Avoid using the literal tag `latest`; this strategy looks at the creation dates of all tags).
- **`name`**: Updates to the tag that is last when sorted alphabetically.
- **`digest`**: Updates to the latest SHA digest of a mutable tag (e.g., tracking a floating `main` tag).

# --- 2. CONFIGURING AN APPLICATION ---
To enable Image Updater for an Application, add the required annotations.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  annotations:
    # 1. Enable Image Updater for this image
    argocd-image-updater.argoproj.io/image-list: my-app=mycompany/guestbook
    
    # 2. Define the update strategy
    argocd-image-updater.argoproj.io/my-app.update-strategy: semver
    
    # 3. Restrict semver updates to the 1.x.x branch
    argocd-image-updater.argoproj.io/my-app.allow-tags: ^1\.
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

# --- 3. HOW IT APPLIES UPDATES ---
By default, the Image Updater uses the **Argo CD API (Parameter Overrides)** to apply the update. 

When it finds a new image (e.g., `v1.5.0`), it calls the Argo CD API to create a parameter override. This behaves exactly the same as if you went into the Argo CD UI and manually changed the image tag in the Application parameters. 

**Warning:** In this default mode, the new image tag is *not* written back to Git. Git still holds the old tag, while Argo CD holds the new tag as an override. This violates the strict "Git is the single source of truth" principle, but it is fast and requires no Git credentials.

Operational Insight
The Argo CD Image Updater drastically simplifies CI pipelines. Developers only need to push a tagged image to the registry; the Image Updater handles the rest. However, the default behavior of overriding parameters via the API means your Git repo will slowly fall out of sync with production. For true GitOps, you must configure the Image Updater to write back to Git, which we will cover tomorrow.
