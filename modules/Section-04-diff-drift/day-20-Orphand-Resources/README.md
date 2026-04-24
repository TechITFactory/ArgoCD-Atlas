# Day 20 — Health Checks & Orphaned Resources

Health Assessment: Argo CD provides built-in health assessment for several standard Kubernetes resources (e.g., ReplicaSets, Pods, Deployments) to determine if they are fully operational (`Healthy`, `Progressing`, `Degraded`, or `Suspended`). A `Degraded` state usually means a resource failed to reach its desired state (like a Pod crash-looping).

Orphaned Resources Monitoring: A feature enabled at the `AppProject` level. It detects "orphaned" Kubernetes resources—resources living in an application's target namespace that are NOT tracked or managed by any Argo CD application. 

Orphaned Resources Exceptions: Some resources are automatically created by cluster operators (like a Cert-Manager `Secret`). You can define `ignore` rules in your `AppProject` so Argo CD doesn't flag them as orphans.

# --- 1. ENABLE ORPHANED RESOURCES MONITORING ---
# This is configured at the Project level, not the Application level.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: default
  namespace: argocd
spec:
  # ... other project settings ...
  orphanedResources:
    warn: true
    ignore:
    - kind: Secret
      name: "*.example.com"
```

Operational Insight
By default, Argo CD only tracks what you tell it to track. If someone manually creates a ConfigMap in your production namespace using `kubectl`, Argo CD won't show it as "OutOfSync" because it's not looking for it. Enabling Orphaned Resources Monitoring solves this "dark matter" problem in your namespaces, ensuring you have 100% visibility into every resource running in your environment, not just the ones defined in Git.

---

## Exercise: Health Checks & Orphaned Resources
> Prerequisites: Days 17–19 complete, guestbook app Synced
> Time: ~40 minutes

---

## Setup — Verify Clean State

```bash
export PATH="$HOME/.local/bin:$PATH"
argocd login 192.168.49.2:31127 --username admin --password ******** --insecure
argocd app get guestbook
```

Expected: `Synced` + `Healthy`

---

## Exercise 1 — Force a Degraded State

**Goal:** Understand what Degraded means and what triggers it.

### Part A: Bad image → Degraded

```bash
# Step 1: Break the deployment with a non-existent image
kubectl set image deployment/guestbook-ui \
  guestbook-ui=gcr.io/heptio-images/ks-guestbook-demo:INVALID_TAG \
  -n guestbook

# Step 2: Watch the health transition
watch kubectl get pods -n guestbook
# You'll see: ErrImagePull → ImagePullBackOff

# Step 3: Check ArgoCD in another terminal
watch argocd app get guestbook
# Health Status: Progressing → Degraded (after ~2 minutes)
# Sync Status: OutOfSync (because we changed it outside Git)
```

**Notice:** Sync is OutOfSync AND Health is Degraded — both problems together.

### Part B: Inspect what caused Degraded

```bash
# ArgoCD resource tree
argocd app resources guestbook

# Detailed events
kubectl describe deployment guestbook-ui -n guestbook | tail -20

# Pod events
kubectl get events -n guestbook \
  --sort-by='.lastTimestamp' | tail -15
```

### Part C: Recover

```bash
argocd app sync guestbook --force
argocd app wait guestbook --health --timeout 120
argocd app get guestbook
```

---

## Exercise 2 — Synced but Degraded

**Goal:** The most dangerous state — confirm the difference.

```bash
# Step 1: Commit a bad image to your "Git" (we simulate with direct sync)
# First sync the app to the broken image to make it Synced+Degraded

# Temporarily disable self-heal so ArgoCD stops fighting us
argocd app set guestbook --self-heal=false

# Now break it AND sync it — so ArgoCD considers it "Synced"
kubectl set image deployment/guestbook-ui \
  guestbook-ui=nginx:nonexistent-tag-12345 \
  -n guestbook

# Force sync so ArgoCD marks it as synced to THIS state
# (in real life, this is you merging a bad PR)
argocd app sync guestbook --force

# Step 2: Wait and observe
sleep 60
argocd app get guestbook

# Expected:
# Sync Status:   Synced        ← ArgoCD thinks everything is fine
# Health Status: Degraded      ← But it's NOT fine
```

**This is why:** Sync tells you about Git alignment. Health tells you if it works.
A CI/CD pipeline that only checks Sync will miss this failure.

```bash
# Step 3: Recover
argocd app set guestbook --self-heal=true
argocd app sync guestbook --force
argocd app wait guestbook --health --timeout 120
argocd app get guestbook
```

---

## Exercise 3 — Custom Lua Health Check

**Goal:** Write a health check for a custom CRD.

### Part A: Create the CRD

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.exercise.example.com
spec:
  group: exercise.example.com
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                engine:
                  type: string
                replicas:
                  type: integer
            status:
              type: object
              x-kubernetes-preserve-unknown-fields: true
      subresources:
        status: {}
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
EOF

kubectl wait --for=condition=established crd/databases.exercise.example.com --timeout=30s
```

### Part B: Create test instances

```bash
# Healthy instance
cat <<EOF | kubectl apply -f -
apiVersion: exercise.example.com/v1
kind: Database
metadata:
  name: db-healthy
  namespace: default
spec:
  engine: postgres
  replicas: 3
EOF

kubectl patch database db-healthy \
  --subresource=status \
  --type=merge \
  -p '{"status":{"phase":"Running","readyReplicas":3,"message":"All replicas healthy"}}'

# Degraded instance
cat <<EOF | kubectl apply -f -
apiVersion: exercise.example.com/v1
kind: Database
metadata:
  name: db-degraded
  namespace: default
spec:
  engine: mysql
  replicas: 3
EOF

kubectl patch database db-degraded \
  --subresource=status \
  --type=merge \
  -p '{"status":{"phase":"Failed","readyReplicas":0,"message":"Disk full on node-2"}}'

# Progressing instance
cat <<EOF | kubectl apply -f -
apiVersion: exercise.example.com/v1
kind: Database
metadata:
  name: db-progressing
  namespace: default
spec:
  engine: postgres
  replicas: 3
EOF

kubectl patch database db-progressing \
  --subresource=status \
  --type=merge \
  -p '{"status":{"phase":"Provisioning","readyReplicas":1,"message":"Starting up..."}}'
```

### Part C: Write and register the Lua health check

```bash
# Write the Lua script to a file first (easier to read)
cat <<'LUAEOF' > /tmp/database-health.lua
hs = {}

if obj.status == nil then
  hs.status = "Progressing"
  hs.message = "Waiting for status"
  return hs
end

local phase = obj.status.phase
local msg   = obj.status.message or ""

if phase == "Running" then
  hs.status  = "Healthy"
  hs.message = msg
  return hs
end

if phase == "Failed" then
  hs.status  = "Degraded"
  hs.message = msg
  return hs
end

if phase == "Provisioning" or phase == "Scaling" then
  hs.status  = "Progressing"
  hs.message = msg
  return hs
end

if phase == "Paused" then
  hs.status  = "Suspended"
  hs.message = msg
  return hs
end

hs.status  = "Progressing"
hs.message = "Unknown phase: " .. (phase or "nil")
return hs
LUAEOF

cat /tmp/database-health.lua

# Now register it in argocd-cm
LUA_SCRIPT=$(cat /tmp/database-health.lua)

kubectl -n argocd patch configmap argocd-cm --type merge \
  -p "{\"data\":{\"resource.customizations.health.exercise.example.com_Database\": $(echo "$LUA_SCRIPT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")}}"
```

### Part D: Restart controller and test

```bash
kubectl -n argocd rollout restart statefulset argocd-application-controller
kubectl -n argocd rollout status statefulset argocd-application-controller

# Create an ArgoCD app pointing to these resources
# (In a real scenario these would be in Git — we deploy them directly for now)

# Check health of each database resource via kubectl
kubectl get databases -n default

# Force ArgoCD to evaluate health
argocd app get guestbook --hard-refresh
```

### Part E: Change a database phase and see health change

```bash
# Transition db-progressing to Running
kubectl patch database db-progressing \
  --subresource=status \
  --type=merge \
  -p '{"status":{"phase":"Running","readyReplicas":3,"message":"All replicas healthy"}}'

# Transition db-healthy to Failed
kubectl patch database db-healthy \
  --subresource=status \
  --type=merge \
  -p '{"status":{"phase":"Failed","readyReplicas":0,"message":"OOM killed"}}'

# View the resources
kubectl get databases -n default
```

---

## Exercise 4 — Orphaned Resources Detection

**Goal:** Enable orphan detection and identify orphaned resources.

### Part A: Enable orphan warnings

```bash
kubectl -n argocd patch application guestbook --type merge \
  -p '{"spec":{"orphanedResources":{"warn":true}}}'

argocd app get guestbook --hard-refresh
argocd app get guestbook
```

### Part B: Create orphaned resources

```bash
# Orphan 1: a ConfigMap nobody owns
kubectl create configmap orphan-1 \
  --from-literal=source="manual kubectl" \
  --from-literal=reason="debugging" \
  -n guestbook

# Orphan 2: a Secret
kubectl create secret generic orphan-2 \
  --from-literal=token="abc123" \
  -n guestbook

# Orphan 3: a Service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: orphan-svc
  namespace: guestbook
spec:
  selector:
    app: orphan
  ports:
    - port: 80
EOF
```

### Part C: View the orphan warnings

```bash
# Via CLI
argocd app get guestbook --hard-refresh
argocd app get guestbook
# Look for WARNINGS section

# List all resources including orphans
argocd app resources guestbook

# Via kubectl — check the app status
kubectl -n argocd get application guestbook \
  -o jsonpath='{.status.conditions}' | python3 -m json.tool
```

Expected warnings:
```
WARNINGS:
OrphanedResource: guestbook  ConfigMap  orphan-1
OrphanedResource: guestbook  Secret     orphan-2
OrphanedResource: guestbook  Service    orphan-svc
```

### Part D: Whitelist an expected orphan

```bash
# The 'default' ServiceAccount and its token are always orphaned
# (Kubernetes creates them automatically in every namespace)
# Add them to the ignore list

kubectl -n argocd patch application guestbook --type merge \
  -p '{
    "spec": {
      "orphanedResources": {
        "warn": true,
        "ignore": [
          {"group": "", "kind": "ServiceAccount", "name": "default"},
          {"group": "", "kind": "Secret", "name": "default-token-*"},
          {"group": "", "kind": "ConfigMap", "name": "orphan-1"}
        ]
      }
    }
  }'

argocd app get guestbook --hard-refresh
argocd app get guestbook
# orphan-1 warning is gone, orphan-2 and orphan-svc still shown
```

---

## Exercise 5 — Auto-Prune Orphaned Resources

**Goal:** Let ArgoCD delete resources that aren't in Git.

```bash
# Step 1: Confirm orphans exist
kubectl get configmap,secret,service -n guestbook | grep orphan

# Step 2: Enable auto-prune and sync
argocd app set guestbook --auto-prune
argocd app sync guestbook

# Step 3: Check if orphans were deleted
kubectl get configmap orphan-1 -n guestbook 2>&1
kubectl get secret orphan-2 -n guestbook 2>&1
kubectl get service orphan-svc -n guestbook 2>&1

# Note: orphan-1 was in the ignore list — did prune respect that?
```

**Observation:** Prune respects `orphanedResources.ignore` — ignored resources
are NOT pruned. Prune only removes resources ArgoCD can identify as no longer
tracked in any app source.

---

## Exercise 6 — Health Status in a Real Rollout

**Goal:** Watch ArgoCD health states transition during a deployment.

```bash
# Step 1: Watch health in real time
watch -n2 "argocd app get guestbook | grep -E 'Health|Sync'"

# Step 2: In another terminal, trigger a rolling update
kubectl set image deployment/guestbook-ui \
  guestbook-ui=gcr.io/heptio-images/ks-guestbook-demo:0.2 \
  -n guestbook

# Watch the transitions:
# Healthy → Progressing (new pods starting) → Healthy (rollout complete)
```

Note the exact seconds when each state transition happens.

---

## Summary Exercise — Put It All Together

Create an Application manifest file that:
1. Deploys guestbook
2. Ignores HPA replica changes (with managedFieldsManagers)
3. Enables orphan detection with the default ServiceAccount whitelisted
4. Has auto-prune enabled
5. Has self-heal enabled

```bash
cat <<EOF > /tmp/guestbook-production.yaml
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
    syncOptions:
      - CreateNamespace=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      managedFieldsManagers:
        - kube-controller-manager
      jsonPointers:
        - /spec/replicas
  orphanedResources:
    warn: true
    ignore:
      - group: ""
        kind: ServiceAccount
        name: default
EOF

kubectl apply -f /tmp/guestbook-production.yaml
argocd app get guestbook --hard-refresh
argocd app get guestbook
```

---

## Cleanup

```bash
# Delete the exercise CRD and instances
kubectl delete database db-healthy db-degraded db-progressing -n default 2>/dev/null || true
kubectl delete crd databases.exercise.example.com 2>/dev/null || true

# Delete any leftover orphans
kubectl delete configmap orphan-1 -n guestbook 2>/dev/null || true
kubectl delete secret orphan-2 -n guestbook 2>/dev/null || true
kubectl delete service orphan-svc -n guestbook 2>/dev/null || true

# Clean temp files
rm /tmp/database-health.lua /tmp/guestbook-production.yaml 2>/dev/null || true

# Final sync and verify
argocd app sync guestbook
argocd app wait guestbook --sync --health --timeout 90
argocd app get guestbook
```

---

## Challenge Exercise (Bonus)

Write a Lua health check for a `CronJob` resource that:
- Returns `Healthy` if the last run succeeded (`lastSuccessfulTime` is set)
- Returns `Degraded` if the last run failed (`lastScheduleTime` is set but `lastSuccessfulTime` is not, and the job has active failures)
- Returns `Progressing` if a job is currently active
- Returns `Suspended` if `spec.suspend == true`

```lua
-- Your Lua health check here
hs = {}

-- Hint: access fields like obj.spec.suspend, obj.status.lastSuccessfulTime
-- obj.status.active is a list of currently running jobs

return hs
```

---

## Key Commands Reference

```bash
# Check health + sync
argocd app get <app>

# List all resources with health
argocd app resources <app>

# Watch health transitions
watch argocd app get <app>

# Enable orphan detection
kubectl -n argocd patch application <app> --type merge \
  -p '{"spec":{"orphanedResources":{"warn":true}}}'

# Enable auto-prune
argocd app set <app> --auto-prune

# Sync and wait for health
argocd app sync <app>
argocd app wait <app> --health --timeout 120

# Restart controller after argocd-cm health check changes
kubectl -n argocd rollout restart statefulset argocd-application-controller
kubectl -n argocd rollout status statefulset argocd-application-controller

# View app conditions (includes orphan warnings)
kubectl -n argocd get application <app> \
  -o jsonpath='{.status.conditions}' | python3 -m json.tool
```
