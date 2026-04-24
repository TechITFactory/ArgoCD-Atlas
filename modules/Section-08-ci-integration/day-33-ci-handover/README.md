# Day 33 — The CI Handover to GitOps

In a traditional imperative CI/CD pipeline, the CI tool (like Jenkins, GitHub Actions, or GitLab CI) runs `kubectl apply` directly against your cluster. 

In a declarative GitOps model with Argo CD, the cluster is strictly fenced off. The CI pipeline never touches the Kubernetes cluster. Instead, the CI pipeline's final action is to push a configuration change to the Git repository. Argo CD takes over from there.

# --- 1. THE RECOMMENDED GITOPS CI WORKFLOW ---

According to the official Argo CD documentation, a standard CI pipeline should look like this:

1. **Build and Test:** The CI server checks out the application source code, runs unit tests, and builds the container image.
2. **Publish Image:** The CI server pushes the new container image (e.g., `v2.0.0`) to the container registry (Docker Hub, ECR, GCR).
3. **Checkout Config Repo:** The CI server checks out the *separate* Git repository containing your Kubernetes manifests (the repo Argo CD is watching).
4. **Update Manifests:** The CI server uses a tool to update the image tag in the manifest.
5. **Commit & Push:** The CI server commits the change and pushes it back to Git.
6. **Deploy:** Argo CD detects the Git commit and synchronizes the cluster to the new image.

# --- 2. EXAMPLE GITHUB ACTIONS PIPELINE ---
Here is an example of the handover step in a CI pipeline using `kustomize` to update the image tag.

```yaml
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    # 1. Build and push your image (omitted for brevity)
    # ...

    # 2. Check out the manifest repository
    - name: Checkout Config Repo
      uses: actions/checkout@v3
      with:
        repository: my-org/guestbook-config
        token: ${{ secrets.GITHUB_PAT }}
        path: config-repo

    # 3. Update the image tag in the manifests
    - name: Update Image Tag
      working-directory: config-repo/overlays/production
      run: |
        # Use kustomize to update the image tag to the new GitHub SHA
        kustomize edit set image mycompany/guestbook:${{ github.sha }}

    # 4. Commit and push the changes back to Git
    - name: Commit and Push
      working-directory: config-repo
      run: |
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add .
        git commit -m "Update guestbook image to ${{ github.sha }}"
        git push
```

# --- 3. SYNCHRONIZING THE APP (OPTIONAL) ---
If you do not have Auto-Sync enabled in Argo CD, or if you want your CI pipeline to wait and verify the deployment was successful, you can use the Argo CD CLI in your pipeline.

```bash
# Download the CLI matching your server version
export ARGOCD_SERVER=argocd.example.com
export ARGOCD_AUTH_TOKEN=<JWT token>

# Trigger a sync and wait for it to become Healthy
argocd app sync guestbook
argocd app wait guestbook
```

Operational Insight
Separating your application source code repo from your Kubernetes manifest config repo is a critical best practice. If you store your manifests in the same repo as your source code, the automated commit from Step 4 will trigger the CI pipeline to run all over again, causing an infinite build loop. Keep them separate: CI handles the code repo, Argo CD handles the config repo, and the commit is the bridge between them.
