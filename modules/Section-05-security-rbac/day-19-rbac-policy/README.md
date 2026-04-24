# Day 23 — RBAC Policy

Built-in Roles: Argo CD has two built-in roles: `role:readonly` (can view applications but not modify them) and `role:admin` (full access to everything). These are assigned via the `policy.default` key in `argocd-rbac-cm`.

RBAC Model Structure: Argo CD RBAC policies follow the Casbin format: `p, <role/user/group>, <resource>, <action>, <object>, <effect>`. Resources include `applications`, `applicationsets`, `clusters`, `repositories`, `logs`, and `exec`.

Policy CSV: All custom RBAC policies are defined in the `policy.csv` key of the `argocd-rbac-cm` ConfigMap. Group assignments (`g, <group>, <role>`) map SSO groups to Argo CD roles.

Deny Effect: You can explicitly deny specific actions using the `deny` effect (e.g., preventing a team from deleting applications while still allowing sync).

# --- 1. CONFIGURE RBAC POLICIES ---
# All RBAC rules go into the argocd-rbac-cm ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default policy for authenticated users (if no other rule matches)
  policy.default: role:readonly

  policy.csv: |
    # --- Custom Roles ---
    # DevOps team: full access to all applications in the "production" project
    p, role:devops, applications, *, production/*, allow

    # Developer team: can view and sync, but NOT delete
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, action/*, */*, allow

    # Explicitly deny developers from deleting apps
    p, role:developer, applications, delete, */*, deny

    # --- Map SSO Groups to Roles ---
    g, my-github-org:devops-team, role:devops
    g, my-github-org:dev-team, role:developer

    # Map a local user to a role
    g, deployer, role:devops
```

# --- 2. VALIDATE RBAC POLICY ---
```bash
argocd admin settings rbac validate \
  --policy-file policy.csv \
  --namespace argocd
```

# --- 3. TEST RBAC POLICY ---
# Check if user "deployer" can sync app "guestbook" in project "default"
```bash
argocd admin settings rbac can deployer sync applications default/guestbook \
  --policy-file policy.csv \
  --namespace argocd
```

# --- 4. VERIFICATION ---
```bash
# Log in as the restricted user and attempt a forbidden action
argocd login <ARGOCD_SERVER> --username deployer --password <PASSWORD>
argocd app delete guestbook
# Expected: permission denied
```

Operational Insight
The golden rule of Argo CD RBAC is: `policy.default: role:readonly`. This ensures that any authenticated user who doesn't match a specific policy can still view applications (for observability) but cannot make changes. Combined with the `deny` effect, you can craft highly granular permissions—for example, allowing a CI bot to sync applications but preventing it from changing the application source or destination.
