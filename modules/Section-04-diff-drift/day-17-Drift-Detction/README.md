# Day 17 — Exercise: Drift Detection
> Prerequisites: ArgoCD running on minikube, argocd CLI in PATH
> Time: ~30 minutes

---

## Setup — Run Once Before All Exercises

```bash
export PATH="$HOME/.local/bin:$PATH"

# Login
argocd login 192.168.49.2:31127 \
  --username admin \
  --password ****** \
  --insecure

# Deploy the sample app
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace guestbook \
  --sync-policy automated \
  --self-heal \
  --auto-prune

# Wait until ready
argocd app wait guestbook --sync --health --timeout 120

# Confirm clean state
argocd app get guestbook
```

Expected output:
```
Sync Status:   Synced
Health Status: Healthy
```

---

## Exercise 1 — Introduce Drift via kubectl Scale

**Goal:** Create drift and confirm ArgoCD detects it.

```bash
# Step 1: Scale the deployment directly (bypass Git)
kubectl scale deployment guestbook-ui --replicas=5 -n guestbook

# Step 2: Check sync status (wait ~30 seconds)
argocd app get guestbook

# Step 3: View the exact diff
argocd app diff guestbook
```

**Expected results:**
- `Sync Status: OutOfSync`
- `Health Status: Healthy`  ← still running, just drifted
- Diff shows `replicas: 5` (live) vs `replicas: 1` (desired)

**Question to answer:** Why is Health still Healthy even though it's OutOfSync?

---

## Exercise 2 — Watch Self-Heal Revert Drift

**Goal:** Observe ArgoCD automatically correcting drift.

```bash
# Step 1: Watch replicas in real time
watch kubectl get deployment guestbook-ui -n guestbook -o wide

# Step 2: In another terminal, check app status
watch argocd app get guestbook
```

**Expected:** Within 30–60 seconds replicas drops back to 1. ArgoCD reverts
to Git state automatically.

---

## Exercise 3 — Disable Self-Heal, Repeat Drift

**Goal:** See what happens when self-heal is off.

```bash
# Step 1: Turn off self-heal
argocd app set guestbook --self-heal=false

# Step 2: Introduce drift again
kubectl scale deployment guestbook-ui --replicas=3 -n guestbook

# Step 3: Wait 60 seconds and check
argocd app get guestbook
# OutOfSync — but replicas stays at 3, ArgoCD does NOT revert

# Step 4: Manually sync to fix it
argocd app sync guestbook

# Step 5: Verify replicas is back to 1
kubectl get deployment guestbook-ui -n guestbook -o jsonpath='{.spec.replicas}'
```

**Expected:** Without self-heal, drift persists until you manually sync.

---

## Exercise 4 — Introduce Label Drift

**Goal:** Drift isn't just replicas — any field counts.

```bash
# Step 1: Add a label directly to the live deployment
kubectl label deployment guestbook-ui -n guestbook env=debug

# Step 2: Check diff
argocd app diff guestbook
# Shows the label in live state but not in Git

# Step 3: Manually sync to clean it up
argocd app sync guestbook

# Step 4: Confirm label is gone
kubectl get deployment guestbook-ui -n guestbook -o jsonpath='{.metadata.labels}'
```

---

## Exercise 5 — Soft Refresh vs Hard Refresh

**Goal:** Understand the difference between refresh types.

```bash
# First, make a change and wait (don't sync yet)
kubectl scale deployment guestbook-ui --replicas=2 -n guestbook

# Soft refresh — re-reads live state, uses cached desired state
argocd app get guestbook --refresh
argocd app get guestbook

# Hard refresh — re-renders manifests from Git AND re-reads live state
argocd app get guestbook --hard-refresh
argocd app get guestbook
```

**When to use each:**
- Soft refresh: after you change something in the cluster
- Hard refresh: after you push new changes to Git

---

## Exercise 6 — Drift on a ConfigMap

**Goal:** Drift happens on any resource type, not just Deployments.

```bash
# Step 1: Find the guestbook ConfigMap (if any)
kubectl get configmap -n guestbook

# Step 2: Create one directly
kubectl create configmap drift-test \
  --from-literal=key=original \
  -n guestbook

# Step 3: Check if ArgoCD detects it
argocd app get guestbook
# This resource isn't in Git — it's ORPHANED, not drifted
# (We'll cover orphaned resources on Day 20)

# Step 4: Modify an existing managed resource instead
# Edit the guestbook-ui service to add an annotation
kubectl annotate service guestbook-ui -n guestbook team=backend

# Step 5: Check the diff
argocd app diff guestbook

# Cleanup
argocd app sync guestbook
kubectl delete configmap drift-test -n guestbook 2>/dev/null || true
```

---

## Cleanup

```bash
# Re-enable self-heal
argocd app set guestbook --self-heal=true
argocd app sync guestbook
argocd app wait guestbook --sync --health --timeout 60
argocd app get guestbook
```

---

## Challenge Exercise (Bonus)

Write a script that:
1. Introduces drift (scale to 4 replicas)
2. Polls `argocd app get guestbook` every 5 seconds
3. Prints the timestamp when it detects `OutOfSync`
4. Prints the timestamp when self-heal returns it to `Synced`
5. Calculates total detection + heal time

```bash
# Starter template — complete this yourself
#!/bin/bash

echo "Introducing drift..."
kubectl scale deployment guestbook-ui --replicas=4 -n guestbook
START=$(date +%s)

# TODO: poll until OutOfSync detected
# TODO: record detection time
# TODO: poll until Synced again
# TODO: print total time
```

---

## Key Commands Reference

```bash
argocd app get <app>                    # status overview
argocd app diff <app>                   # see exact diff
argocd app sync <app>                   # manually sync
argocd app get <app> --refresh          # soft refresh
argocd app get <app> --hard-refresh     # hard refresh
argocd app set <app> --self-heal=true   # enable self-heal
argocd app set <app> --self-heal=false  # disable self-heal
kubectl scale deployment <name> --replicas=N -n <ns>
```
