# Day 21 — SSO Concepts

Local Users/Accounts: Argo CD has a built-in user management system. Users are defined directly in the `argocd-cm` ConfigMap. This is suitable for small teams but does NOT scale for enterprise use because it requires manual password management and has no centralized identity governance.

SSO (Single Sign-On): The production-recommended approach for authenticating to Argo CD. It integrates with external Identity Providers (IdPs) so users log in once with their corporate credentials (e.g., Google, Okta, Azure AD) and are automatically authenticated across all connected services.

Dex: A lightweight OIDC (OpenID Connect) connector bundled with Argo CD. It acts as a bridge between Argo CD and third-party IdPs (GitHub, LDAP, SAML, etc.). Dex handles the OAuth2 flow and passes back user identity and group claims to Argo CD.

Existing OIDC Provider: If your organization already has a centralized OIDC provider (like Okta or Keycloak), Argo CD can connect to it directly without needing Dex.

# --- 1. CREATE A LOCAL USER ---
# Local users are defined in the argocd-cm ConfigMap.
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
  # Define a new local user called "deployer"
  # apiKey = can generate API tokens, login = can log in via UI/CLI
  accounts.deployer: apiKey, login
  accounts.deployer.enabled: "true"
```

# --- 2. SET PASSWORD FOR LOCAL USER ---
```bash
argocd account update-password --account deployer --new-password '<NEW_PASSWORD>'
```

# --- 3. CONFIGURE SSO WITH DEX (GITHUB EXAMPLE) ---
# This is the recommended production approach.
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
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

# --- 4. DISABLE THE BUILT-IN ADMIN ACCOUNT (Production Best Practice) ---
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  admin.enabled: "false"
```

# --- 5. VERIFICATION ---
```bash
# List all accounts
argocd account list

# Get details for a specific account
argocd account get --account deployer
```

Operational Insight
In production, the built-in `admin` account should be disabled after SSO is configured. Local accounts are acceptable for CI/CD service accounts (using API keys only, with `login` disabled), but human users should always authenticate through SSO. This ensures centralized audit trails, automatic deprovisioning when employees leave, and enforcement of corporate MFA policies.
