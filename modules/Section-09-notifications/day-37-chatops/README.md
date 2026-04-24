# Day 37 — ChatOps with Slack

While email is useful, modern engineering teams rely on ChatOps (Slack, Microsoft Teams, Discord) for real-time observability. Integrating Argo CD with Slack allows developers to see deployment failures instantly in their team channels.

Because we installed the **Notifications Catalog** in Day 36, Argo CD already knows exactly how to format beautiful, rich-text Slack messages with color-coded blocks and buttons linking directly to the Argo CD UI.

All we need to do is provide a Slack OAuth Token and configure the subscription.

# --- 1. GET A SLACK TOKEN ---
1. Create a Slack App in your workspace.
2. Grant it the `chat:write` bot scope.
3. Install the app to your workspace and copy the generated **Bot User OAuth Token** (starts with `xoxb-`).

# --- 2. CONFIGURE THE SLACK SERVICE ---
Add the token to the notifications Secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
stringData:
  # Notice the key starts with slack-token
  slack-token: xoxb-your-slack-bot-token-here
type: Opaque
```

Enable the Slack service in the ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
```

# --- 3. CONFIGURE UI DEEP LINKS ---
For the Slack messages to include a clickable button that takes the user directly to the failing Application, Argo CD needs to know its own public URL. Configure this in `argocd-cm`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # The public facing URL of your Argo CD UI
  url: https://argocd.mycompany.com
```

# --- 4. SUBSCRIBE TO SLACK NOTIFICATIONS ---
Add the annotation to your Application, specifying the Slack channel name (or ID). Ensure your Slack Bot is invited to that channel in your Slack workspace.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  annotations:
    # Send to the #deployments channel on failure
    notifications.argoproj.io/subscribe.on-sync-failed.slack: "deployments"
    
    # Send to the #deployments channel on success
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: "deployments"
spec:
  # ... standard application spec
```

Operational Insight
Combining ChatOps with ApplicationSets (Section 6) creates a zero-touch developer experience. A developer opens a Pull Request, the PR Generator creates an ephemeral preview environment, and the `on-created` notification trigger pings the developer on Slack with a direct link to their preview app. When the PR merges, the app is deleted, and Slack is updated. This tight feedback loop is the ultimate goal of an Internal Developer Platform.
