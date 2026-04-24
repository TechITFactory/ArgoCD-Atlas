# Day 18 — Exercise: Diff Strategies

> **What is this about?**
> ArgoCD compares what's in Git vs what's running in the cluster to decide if
> an app is "Synced" or "OutOfSync". But sometimes it gets it WRONG.
>
> The way ArgoCD does this comparison is called the **Diff Strategy**.
> There are two strategies:
> - **Legacy Diff** (default) — ArgoCD does the comparison itself locally
> - **Server-Side Diff** — ArgoCD asks Kubernetes to simulate the apply and compare
>
> In this exercise you'll see WHY Legacy fails and HOW Server-Side Diff fixes it.
>
> **Prerequisites:** Day 17 complete, guestbook app deployed and Synced
> **Time:** ~35 minutes
>
> ⚠️ **Important — Do exercises IN ORDER.**
> Exercise 2 (seeing the false positive) MUST be done before Exercise 5 (enabling SSD globally).
> If SSD is already ON, the false positive won't appear — that's the whole point of SSD.
> If you've already enabled SSD, run the "Reset to Legacy Diff" step below first.

---

## Setup — Check Clean State

```bash
argocd login 192.168.49.2:31127 --username admin --password dtrbKIYySPRlSBzn --insecure
argocd app get guestbook
```

You should see: `Sync Status: Synced` and `Health Status: Healthy`

If not synced: `argocd app sync guestbook`

---

### Reset to Legacy Diff (run this if you've already done Exercise 5)

> If Server-Side Diff is already enabled, Exercise 2 won't show the false positive.
> Run this first to go back to Legacy mode, then follow the exercises in order.

```bash
# Step 1: Disable global Server-Side Diff
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  controller.diff.server.side: "false"
EOF

kubectl -n argocd rollout restart statefulset argocd-application-controller
kubectl -n argocd rollout status statefulset argocd-application-controller

# Step 2: IMPORTANT — also remove the per-app annotation if it was set
# The per-app annotation overrides the global flag, so both must be cleared
kubectl -n argocd annotate application guestbook argocd.argoproj.io/compare-options-
# The trailing dash (-) deletes the annotation

# Step 3: Hard refresh to apply changes
argocd app get guestbook --hard-refresh
argocd app get guestbook
```

> ⚠️ **Common gotcha:** The per-app annotation (`argocd.argoproj.io/compare-options`)
> always takes priority over the global ConfigMap setting.
> If you set SSD per-app in Exercise 3, you MUST remove that annotation too —
> otherwise the global "false" has no effect on that app.

---

## Exercise 1 — Check Which Diff Strategy You're Currently Using

**Goal:** Understand what mode ArgoCD is in before we change anything.

```bash
kubectl -n argocd get configmap argocd-cmd-params-cm -o yaml | grep -i "diff"
```

**What to look for:**
- If you see `controller.diff.server.side: "true"` → Server-Side Diff is ON
- If the line is missing entirely → you are using **Legacy Diff** (the default)

Check the controller logs too:

```bash
kubectl -n argocd logs statefulset/argocd-application-controller --tail=20 | grep -i "diff"
```

---

## Exercise 2 — See the Problem with Legacy Diff

### The Problem (in plain English)

> **What is an admission webhook?**
> It's like a bouncer at a door. Every time you create/update something in Kubernetes,
> the webhook intercepts it and can MODIFY it before saving.
>
> **Real examples:**
> - **Istio** injects a `sidecar.istio.io/status` annotation on every pod
> - **cert-manager** injects a `caBundle` into webhook configs
> - **Kyverno** adds policy-enforcement labels
>
> **The problem:** These annotations are added at runtime — they are NOT in your Git files.
> Legacy Diff sees: "Git has no annotation, cluster has annotation → MISMATCH!"
> This is a **false positive** — the app is fine, but ArgoCD is panicking.

---

### Step 1 — Confirm the app is clean

```bash
argocd app get guestbook
```

Expected: `Sync Status: Synced`

---

### Step 2 — Simulate drift: change the image tag directly

> We simulate what happens when someone hotfixes the image manually,
> or a CI tool updates the image without going through Git.

```bash
kubectl set image deployment/guestbook-ui \
  guestbook-ui=gcr.io/heptio-images/ks-guestbook-demo:0.2 \
  -n guestbook
```

Git says `image: ...ks-guestbook-demo:0.1` — cluster now has `:0.2`.

---

### Step 3 — Watch ArgoCD complain

```bash
argocd app get guestbook --hard-refresh
argocd app get guestbook
```

Expected: `Sync Status: OutOfSync`

```bash
argocd app diff guestbook
```

You'll see:
```
-  image: gcr.io/heptio-images/ks-guestbook-demo:0.1   ← Git
+  image: gcr.io/heptio-images/ks-guestbook-demo:0.2   ← cluster
```

This is real drift — the live image doesn't match what Git defines.

---

## Exercise 3 — Fix it for ONE App using Server-Side Diff

### How Server-Side Diff works

> **Legacy Diff:** ArgoCD downloads the Git manifest and the live resource, then compares them locally.
> It has no idea what the webhook would add.
>
> **Server-Side Diff:** ArgoCD sends the Git manifest to Kubernetes with `--dry-run=server`.
> Kubernetes runs the admission webhooks on it and returns what the resource WOULD look like.
> Now ArgoCD compares "webhook-processed Git manifest" vs "live resource" → they match!

---

### Step 1 — Enable Server-Side Diff for guestbook only

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  annotations:
    argocd.argoproj.io/compare-options: ServerSideDiff=true
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
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
EOF
```

---

### Step 2 — Force ArgoCD to re-compare

```bash
argocd app get guestbook --hard-refresh
```

> **What is hard-refresh?**
> A normal refresh reads from ArgoCD's cache.
> A hard refresh forces ArgoCD to re-fetch from the cluster and re-run the diff right now.

---

### Step 3 — Check the result

```bash
argocd app get guestbook
```

Expected: `Sync Status: Synced` ← false positive is gone!

```bash
argocd app diff guestbook
```

Expected: empty output — no differences.

---

## Exercise 4 — Debug Mode: See Exactly What a Webhook Injects

> **When would you use this?**
> When you want to understand what a webhook is actually adding to your resource.
> Useful for debugging "why is this field appearing?"

---

### Step 1 — Enable debug mode

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  annotations:
    argocd.argoproj.io/compare-options: ServerSideDiff=true,IncludeMutationWebhook=true
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
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
EOF
```

---

### Step 2 — Hard refresh and check diff

```bash
argocd app get guestbook --hard-refresh
argocd app diff guestbook
```

> Now you'll see the injected annotations appear in the diff again.
> This is **intentional** — you're in debug mode to see what the webhook added.
> Use this when investigating what a specific webhook is injecting.

---

### Step 3 — Turn off debug mode, go back to normal SSD

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  annotations:
    argocd.argoproj.io/compare-options: ServerSideDiff=true
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
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
EOF

argocd app get guestbook --hard-refresh
argocd app get guestbook
```

Expected: `Sync Status: Synced`

---

## Exercise 5 — Enable Server-Side Diff for ALL Apps Globally

> **When to use this?**
> When you have many apps and want Server-Side Diff everywhere without
> annotating each one individually.

---

### Step 1 — Apply the global config

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  controller.diff.server.side: "true"
EOF
```

---

### Step 2 — Restart the controller to pick up the change

> Config changes to `argocd-cmd-params-cm` require a controller restart.
> The controller is a StatefulSet (not a Deployment), so we restart it differently.

```bash
kubectl -n argocd rollout restart statefulset argocd-application-controller
kubectl -n argocd rollout status statefulset argocd-application-controller
```

Wait until you see: `statefulset rolling update complete`

---

### Step 3 — Verify the flag is active

```bash
kubectl -n argocd get configmap argocd-cmd-params-cm \
  -o jsonpath='{.data.controller\.diff\.server\.side}'
```

Expected output: `true`

---

### Step 4 — Confirm guestbook is still Synced

```bash
argocd app get guestbook --hard-refresh
argocd app get guestbook
```

Expected: `Sync Status: Synced`

---

## Exercise 6 — Fix False Positives from Status Fields

### The Problem (in plain English)

> **What is a `status` field?**
> In Kubernetes, every resource has a `spec` (what you want) and a `status` (what Kubernetes reports).
> You write `spec`. Kubernetes writes `status` — you never put `status` in your Git files.
>
> **Common mistake:** Someone exports a live resource with `kubectl get -o yaml` and commits it to Git.
> That export includes the `status` block. Now ArgoCD sees: "Git has `status.readyReplicas: 1` but
> the cluster has `status.readyReplicas: 3`" → OutOfSync forever.

---

### Step 1 — Create a deployment with a status block (the mistake)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: status-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: status-test
  template:
    metadata:
      labels:
        app: status-test
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
status:
  readyReplicas: 1
  replicas: 1
  availableReplicas: 1
EOF

# Kubernetes ignores what you wrote in status and manages it itself
kubectl get deployment status-test -o jsonpath='{.status}' | python3 -m json.tool
```

The actual status will look different from what you wrote — Kubernetes controls it.

---

### Step 2 — Fix it globally: tell ArgoCD to ignore all status fields

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  resource.compareoptions: |
    ignoreResourceStatusField: all
EOF
```

Now ArgoCD will never report OutOfSync because of a `status` field mismatch.

---

### Step 3 — Cleanup the test deployment

```bash
kubectl delete deployment status-test
```

---

## Quick Reference — Copy-Paste Blocks

### Per-App: Server-Side Diff

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <your-app>
  namespace: argocd
  annotations:
    argocd.argoproj.io/compare-options: ServerSideDiff=true
spec:
  # ... rest of your app spec
EOF
```

### Global: Server-Side Diff ON

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  controller.diff.server.side: "true"
EOF
kubectl -n argocd rollout restart statefulset argocd-application-controller
```

### Global: Server-Side Diff OFF (reset)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  controller.diff.server.side: "false"
EOF
kubectl -n argocd rollout restart statefulset argocd-application-controller
```

### Global: Ignore status fields

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  resource.compareoptions: |
    ignoreResourceStatusField: all
EOF
```

---

## Cleanup

```bash
# Reset image back to original
kubectl set image deployment/guestbook-ui \
  guestbook-ui=gcr.io/heptio-images/ks-guestbook-demo:0.1 \
  -n guestbook

argocd app sync guestbook
argocd app wait guestbook --sync --health --timeout 60
argocd app get guestbook
```

---

## Challenge Exercise (Bonus)

**Scenario:** Your cluster uses an internal admission controller that automatically
adds a `last-checked-by: security-scanner` annotation on every Deployment.

1. Simulate this by patching `guestbook-ui` to add the annotation
2. Confirm Legacy Diff reports OutOfSync
3. Switch guestbook to Server-Side Diff using a `cat <<EOF` heredoc (no saving files)
4. Confirm ArgoCD shows Synced again
5. Restart the application controller and confirm it stays Synced

```bash
# Write your cat <<EOF | kubectl apply -f - command here
```

---

## Handy Commands

```bash
# Check which diff strategy is active
kubectl -n argocd get configmap argocd-cmd-params-cm -o yaml | grep diff

# Force re-comparison right now
argocd app get guestbook --hard-refresh

# Check diff output (should be empty when working correctly)
argocd app diff guestbook

# Restart controller (needed after argocd-cmd-params-cm changes)
kubectl -n argocd rollout restart statefulset argocd-application-controller
kubectl -n argocd rollout status statefulset argocd-application-controller

# Remove an annotation from an app
kubectl -n argocd annotate application guestbook argocd.argoproj.io/compare-options-
# The trailing dash (-) means DELETE the annotation
```
