Resource Hooks: Specialized Kubernetes resources (typically Jobs or Pods) that Argo CD executes at specific points in the deployment lifecycle. They are defined using the `argocd.argoproj.io/hook` annotation.

Sync Phases: The specific stages in the Argo CD sync lifecycle where hooks can be triggered. Common phases include `PreSync`, `Sync`, `PostSync`, and `SyncFail`.

Hook Deletion Policy: A configuration that dictates when Argo CD should clean up the hook resource (e.g., deleting a Job after it succeeds) using the `argocd.argoproj.io/hook-delete-policy` annotation.

Sync Waves: A method to define the exact deployment order of resources and hooks within a specific phase using the `argocd.argoproj.io/sync-wave` annotation (lower values execute first).

# --- 1. PRESYNC HOOK (DATABASE MIGRATION) ---
# This Job will execute BEFORE any other application resources are synced.
# If this job fails, the entire sync process stops and fails.
cat <<EOF > 01-presync-migration.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "-1"
spec:
  template:
    spec:
      containers:
      - name: db-migrate
        image: bitnami/postgresql:latest
        command: ["psql", "-h", "db-host", "-U", "admin", "-c", "SELECT 1;"]
      restartPolicy: Never
  backoffLimit: 1
EOF

# --- 2. POSTSYNC HOOK (SLACK NOTIFICATION) ---
# This Job runs AFTER the application has successfully synced.
cat <<EOF > 02-postsync-notification.yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: slack-notification-
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: slack-notify
        image: curlimages/curl
        command: 
        - curl
        - -X
        - POST
        - --data-urlencode
        - 'payload={"text": "App Sync Succeeded!"}'
        - https://hooks.slack.com/services/YOUR/WEBHOOK/URL
      restartPolicy: Never
  backoffLimit: 2
EOF

# --- 3. APPLY COMMANDS ---
kubectl apply -f 01-presync-migration.yaml
kubectl apply -f 02-postsync-notification.yaml

# --- 4. VERIFICATION ---
# Watch the sync process via the Argo CD CLI to see the hooks execute in order
argocd app sync your-app-name --async
argocd app wait your-app-name

Operational Insight
Hooks and Waves transform Argo CD from a simple YAML applier into a robust orchestration engine. By using \`PreSync\` hooks for tasks like database migrations or security scans, you prevent broken code from being deployed. Pairing this with \`hook-delete-policy: HookSucceeded\` ensures your cluster doesn't get cluttered with completed jobs, maintaining a clean state while handling complex deployment lifecycles gracefully.
