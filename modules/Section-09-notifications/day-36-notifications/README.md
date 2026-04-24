# Day 36 — Argo CD Notifications Basics

Argo CD Notifications continuously monitors your Argo CD Applications and provides a flexible way to alert users about important changes in the application state (e.g., sync failures, successful deployments, health degradation).

The notification system is built around three core concepts:
1. **Services:** The destination platforms (Slack, Email, PagerDuty, GitHub, Teams).
2. **Triggers and Templates:** "When" to send the alert, and "What" the alert should say.
3. **Subscriptions:** How you connect a specific Application to a Trigger and Service.

# --- 1. INSTALL THE CATALOG ---
Instead of writing your own triggers and templates from scratch, Argo CD provides a massive catalog of pre-built, community-tested templates.

```bash
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml
```

# --- 2. CONFIGURE A SERVICE (EMAIL EXAMPLE) ---
To send a notification, you must first authenticate Argo CD with the external service. You store the credentials in a Secret, and the configuration in a ConfigMap.

**1. Create the Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
stringData:
  email-username: admin@mycompany.com
  email-password: super-secret-password
type: Opaque
```

**2. Configure the ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.email.gmail: |
    username: $email-username
    password: $email-password
    host: smtp.gmail.com
    port: 465
    from: $email-username
```

# --- 3. SUBSCRIBE TO NOTIFICATIONS ---
Once the service is configured, you tell an Argo CD Application to send alerts by adding an annotation. The annotation format is:
`notifications.argoproj.io/subscribe.<trigger>.<service>: <destination>`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  annotations:
    # Send an email if the sync fails
    notifications.argoproj.io/subscribe.on-sync-failed.email: "dev-team@mycompany.com"
    # Send an email if the sync succeeds
    notifications.argoproj.io/subscribe.on-sync-succeeded.email: "dev-team@mycompany.com"
spec:
  # ... standard application spec
```

Operational Insight
Argo CD Notifications is decoupled from the main Argo CD core; it runs as a separate controller (`argocd-notifications-controller`). The catalog is incredibly powerful—it includes templates that automatically format GitHub PR comments or rich Slack blocks. You should almost never write your own templates; always start by installing the official catalog.
