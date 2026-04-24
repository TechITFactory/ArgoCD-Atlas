# Day 22 — SSO Setup (Hands-On)

SSO Flow: When a user clicks "Login via SSO" in the Argo CD UI, Argo CD redirects them to the Dex server. Dex then redirects to the external IdP (e.g., GitHub). After the user authenticates, the IdP sends a token back to Dex, which forwards the user's identity and group claims to Argo CD.

Client Secret Management: SSO client secrets should NEVER be stored in plain text in the `argocd-cm` ConfigMap. Instead, store them in the `argocd-secret` Secret and reference them using the `$variable` syntax.

Callback URL: When registering your application in the IdP, the callback URL must be set to `https://<argocd-url>/api/dex/callback` for Dex, or `https://<argocd-url>/auth/callback` for a direct OIDC provider.

# --- 1. STORE CLIENT SECRET SECURELY ---
# Secrets are stored in argocd-secret, NOT in argocd-cm
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
stringData:
  # GitHub OAuth App credentials
  dex.github.clientID: "your-github-client-id"
  dex.github.clientSecret: "your-github-client-secret"
```

# --- 2. CONFIGURE DEX IN argocd-cm ---
# Reference the secrets using $ prefix
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
    - type: github
      id: github
      name: GitHub
      config:
        clientID: $dex.github.clientID
        clientSecret: $dex.github.clientSecret
        orgs:
        - name: your-github-org
```

# --- 3. CONFIGURE DIRECT OIDC (Without Dex) ---
# For organizations with an existing OIDC provider (e.g., Okta, Keycloak)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Okta
    issuer: https://your-org.okta.com
    clientID: $oidc.okta.clientID
    clientSecret: $oidc.okta.clientSecret
    requestedScopes:
    - openid
    - profile
    - email
    - groups
```

# --- 4. RESTART DEX AFTER CONFIGURATION ---
```bash
kubectl -n argocd rollout restart deployment argocd-dex-server
kubectl -n argocd rollout status deployment argocd-dex-server
```

# --- 5. VERIFICATION ---
```bash
# Check Dex logs for successful connector registration
kubectl -n argocd logs deployment/argocd-dex-server | head -20

# Test login via CLI (will open browser for SSO)
argocd login argocd.example.com --sso
```

Operational Insight
The most common mistake in SSO setup is an incorrect callback URL. For Dex-based SSO, the callback URL registered in your IdP MUST be `https://<argocd-url>/api/dex/callback`. For direct OIDC, it is `https://<argocd-url>/auth/callback`. A mismatch will cause a "redirect_uri_mismatch" error. Always store secrets in `argocd-secret` using the `$variable` reference pattern—never hardcode them in ConfigMaps.
