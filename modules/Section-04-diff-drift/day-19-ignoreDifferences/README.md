# Day 19 — Ignore Differences
> Prerequisites: Day 18 complete, guestbook app Synced, Server-Side Diff enabled
> Time: ~35 minutes

Diff Customization (ignoreDifferences): A mechanism to instruct Argo CD to ignore drift on specific fields of a Kubernetes resource. This is crucial when external controllers (like an HPA or mutating webhooks) modify fields that are not defined in Git.

Application Level Configuration: You can configure `ignoreDifferences` directly within the Argo CD `Application` spec. You specify the target resource (by group and kind) and point to the ignored fields using JSON pointers (e.g., `/spec/replicas`) or JQ path expressions.

System-Level Configuration: For global exceptions, you can configure ignored differences in the `argocd-cm` ConfigMap so they apply to all applications across the cluster automatically.

managedFieldsManagers: A feature allowing Argo CD to ignore any fields that are owned by a specific Kubernetes controller (e.g., `kube-controller-manager` for HPA), avoiding the need to manually list every JSON pointer.

# --- 1. APPLICATION SPEC: IGNORE DIFFERENCES ---
# This ignores the replicas field for all Deployment resources in this application
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```

# --- 2. ADVANCED: IGNORE MANAGED FIELDS ---
# This ignores any changes made by the HPA controller (kube-controller-manager)
```yaml
spec:
  ignoreDifferences:
  - group: "*"
    kind: "*"
    managedFieldsManagers:
    - kube-controller-manager
```

Operational Insight
In modern Kubernetes, Git is rarely the *only* thing mutating cluster state. Service meshes inject sidecars, HPAs scale replicas, and admission controllers add labels. Without `ignoreDifferences`, your applications would be permanently stuck in an `OutOfSync` state, leading to endless reconciliation loops and notification fatigue. Proper use of diff customization allows GitOps to peacefully coexist with cluster automation.---

## Setup — Verify Clean State

```bash
export PATH="$HOME/.local/bin:$PATH"
argocd login 192.168.49.2:31127 --username admin --password dtrbKIYySPRlSBzn --insecure
argocd app get guestbook
```

Expected: `Synced` + `Healthy`

---

## Exercise 1 — The HPA Replicas Problem

**Goal:** Reproduce and fix the ArgoCD vs HPA fight.

### Part A: Create the conflict

```bash
# Step 1: Create an HPA for guestbook
kubectl autoscale deployment guestbook-ui \
  -n guestbook \
  --cpu-percent=50 \
  --min=1 \
  --max=5

kubectl get hpa -n guestbook

# Step 2: Simulate HPA scaling (set replicas directly)
kubectl scale deployment guestbook-ui --replicas=3 -n guestbook

# Step 3: Check ArgoCD — it should show OutOfSync
sleep 20
argocd app get guestbook
argocd app diff guestbook
# Diff shows: replicas: 3 (live) vs replicas: 1 (git)
```

### Part B: Apply ignoreDifferences (without managedFieldsManagers)

```bash
# Step 1: Patch the application
kubectl -n argocd patch application guestbook \
  --type merge \
  -p '{
    "spec": {
      "ignoreDifferences": [
        {
          "group": "apps",
          "kind": "Deployment",
          "jsonPointers": ["/spec/replicas"]
        }
      ]
    }
  }'

# Step 2: Hard refresh
argocd app get guestbook --hard-refresh
argocd app get guestbook
# Sync Status: Synced  ← diff ignored

# Step 3: BUT does sync overwrite replicas?
argocd app sync guestbook
kubectl get deployment guestbook-ui -n guestbook \
  -o jsonpath='{.spec.replicas}{"\n"}'
# Check if it reset to 1 — it might!
```

### Part C: Add managedFieldsManagers to prevent sync overwrite

```bash
# Step 1: Update with managedFieldsManagers
kubectl -n argocd patch application guestbook \
  --type merge \
  -p '{
    "spec": {
      "ignoreDifferences": [
        {
          "group": "apps",
          "kind": "Deployment",
          "managedFieldsManagers": ["kube-controller-manager"],
          "jsonPointers": ["/spec/replicas"]
        }
      ]
    }
  }'

# Step 2: Scale to 4 and sync — replicas should NOT be reset
kubectl scale deployment guestbook-ui --replicas=4 -n guestbook
argocd app sync guestbook
kubectl get deployment guestbook-ui -n guestbook \
  -o jsonpath='{.spec.replicas}{"\n"}'
# Should stay at 4 — ArgoCD didn't touch it
```

---

## Exercise 2 — Ignore cert-manager caBundle (Simulated)

**Goal:** Configure the global ignore rule for webhook caBundle injection.

### Part A: Create the fake webhook

```bash
cat <<EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: exercise-webhook
webhooks:
  - name: exercise.example.com
    admissionReviewVersions: ["v1"]
    clientConfig:
      url: "https://example.com/validate"
      caBundle: ""
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: ["apps"]
        apiVersions: ["v1"]
        resources: ["deployments"]
    sideEffects: None
    failurePolicy: Ignore
EOF
```

### Part B: Simulate cert-manager injecting the caBundle

```bash
# cert-manager does this automatically — we simulate it
FAKE_CA=$(echo "fake-ca-bundle-data" | base64 -w0)

kubectl patch validatingwebhookconfiguration exercise-webhook \
  --type='json' \
  -p="[{\"op\":\"replace\",\"path\":\"/webhooks/0/clientConfig/caBundle\",\"value\":\"${FAKE_CA}\"}]"

# Confirm the caBundle is now set
kubectl get validatingwebhookconfiguration exercise-webhook \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d
```

### Part C: Add global ignore rule to argocd-cm

```bash
kubectl -n argocd patch configmap argocd-cm --type merge -p '{
  "data": {
    "resource.customizations.ignoreDifferences.admissionregistration.k8s.io_ValidatingWebhookConfiguration": "jqPathExpressions:\n  - .webhooks[].clientConfig.caBundle\n",
    "resource.customizations.ignoreDifferences.admissionregistration.k8s.io_MutatingWebhookConfiguration": "jqPathExpressions:\n  - .webhooks[].clientConfig.caBundle\n"
  }
}'

# Restart controller to apply
kubectl -n argocd rollout restart statefulset argocd-application-controller
kubectl -n argocd rollout status statefulset argocd-application-controller
```

### Part D: Verify

```bash
# Any app managing webhook configs will now ignore caBundle in diff
argocd app get guestbook --hard-refresh
argocd app get guestbook
```

---

## Exercise 3 — ignoreDifferences with jqPathExpressions

**Goal:** Target nested array fields using jq syntax.

```bash
# Scenario: ignore all container image fields in a Deployment
# (useful when image-updater is managing images outside of Git)

kubectl -n argocd patch application guestbook \
  --type merge \
  -p '{
    "spec": {
      "ignoreDifferences": [
        {
          "group": "apps",
          "kind": "Deployment",
          "managedFieldsManagers": ["kube-controller-manager"],
          "jsonPointers": ["/spec/replicas"]
        },
        {
          "group": "apps",
          "kind": "Deployment",
          "jqPathExpressions": [
            ".spec.template.spec.containers[].image"
          ]
        }
      ]
    }
  }'

# Test it: change the image directly
kubectl set image deployment/guestbook-ui \
  guestbook-ui=gcr.io/heptio-images/ks-guestbook-demo:0.2 \
  -n guestbook

# Wait and check
sleep 20
argocd app get guestbook --hard-refresh
argocd app get guestbook
# Should be Synced — image diff is ignored

argocd app diff guestbook
# Should be empty
```

---

## Exercise 4 — Declarative ignoreDifferences in a YAML File

**Goal:** Store ignoreDifferences in Git (the right way).

```bash
# Create the full Application manifest with ignoreDifferences baked in
cat <<EOF > /tmp/guestbook-with-ignore.yaml
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
    - group: apps
      kind: Deployment
      jqPathExpressions:
        - .spec.template.spec.containers[].image
EOF

# Apply it
kubectl apply -f /tmp/guestbook-with-ignore.yaml

# Verify
argocd app get guestbook --hard-refresh
argocd app get guestbook

# Read back what was applied
kubectl -n argocd get application guestbook \
  -o jsonpath='{.spec.ignoreDifferences}' | python3 -m json.tool
```

---

## Exercise 5 — Verify ignoreDifferences Does NOT Prevent Prune

**Goal:** Confirm ignored fields still get cleaned up when they should.

```bash
# ignoreDifferences only skips diff REPORTING
# It does not protect resources from being pruned when removed from Git

# Add a label to the deployment (something in Git controls)
kubectl label deployment guestbook-ui -n guestbook test-label=exercise5

# Check diff (this label is NOT in ignoreDifferences so it shows)
argocd app diff guestbook

# Sync — ArgoCD should remove the label (it's not in Git)
argocd app sync guestbook

# Confirm label is gone
kubectl get deployment guestbook-ui -n guestbook \
  -o jsonpath='{.metadata.labels}' | python3 -m json.tool
```

---

## Reference YAML Snippets

Save these in your notes — you'll use them constantly in production.

### HPA Replicas Fix
```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    managedFieldsManagers:
      - kube-controller-manager
    jsonPointers:
      - /spec/replicas
```

### cert-manager caBundle Fix (in argocd-cm)
```yaml
data:
  resource.customizations.ignoreDifferences.admissionregistration.k8s.io_ValidatingWebhookConfiguration: |
    jqPathExpressions:
      - .webhooks[].clientConfig.caBundle
  resource.customizations.ignoreDifferences.admissionregistration.k8s.io_MutatingWebhookConfiguration: |
    jqPathExpressions:
      - .webhooks[].clientConfig.caBundle
```

### Image Updater Pattern
```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jqPathExpressions:
      - .spec.template.spec.containers[].image
      - .spec.template.spec.initContainers[].image
```

### Istio Sidecar Annotation Fix
```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jqPathExpressions:
      - .spec.template.metadata.annotations["sidecar.istio.io/status"]
      - .spec.template.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"]
```

---

## Cleanup

```bash
kubectl delete hpa guestbook-ui -n guestbook 2>/dev/null || true
kubectl delete validatingwebhookconfiguration exercise-webhook 2>/dev/null || true
rm /tmp/guestbook-with-ignore.yaml /tmp/bad-manifest.yaml 2>/dev/null || true

# Reset image to original
kubectl set image deployment/guestbook-ui \
  guestbook-ui=gcr.io/heptio-images/ks-guestbook-demo:0.1 \
  -n guestbook 2>/dev/null || true

argocd app sync guestbook
argocd app wait guestbook --sync --health --timeout 90
argocd app get guestbook
```

---

## Challenge Exercise (Bonus)

Your cluster has these three live situations:
1. ArgoRollout is managing replica counts via `spec.replicas`
2. cert-manager is rotating `caBundle` on 3 webhook configs every 24h
3. Istio is injecting `sidecar.istio.io/status` annotations on all Deployments

Write a single `argocd-cm` patch that fixes ALL three globally,
with zero per-app configuration changes needed.

```bash
# Your answer here — write the kubectl patch command
```

---

## Key Commands Reference

```bash
# View current ignoreDifferences on an app
kubectl -n argocd get application <app> \
  -o jsonpath='{.spec.ignoreDifferences}' | python3 -m json.tool

# Patch ignoreDifferences on an app
kubectl -n argocd patch application <app> --type merge \
  -p '{"spec":{"ignoreDifferences":[...]}}'

# Add global ignore rule
kubectl -n argocd patch configmap argocd-cm --type merge \
  -p '{"data":{"resource.customizations.ignoreDifferences.<group>_<Kind>":"..."}}'

# Restart controller after argocd-cm changes
kubectl -n argocd rollout restart statefulset argocd-application-controller

# Hard refresh
argocd app get <app> --hard-refresh

# View the diff (should be empty after correct ignoreDifferences)
argocd app diff <app>
```
