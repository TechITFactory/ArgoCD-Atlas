Context: Refers to the specific Argo CD server instance the CLI is currently interacting with. You can manage multiple Argo CD environments by switching contexts.

App Create vs. App Set: * app create: Used for the initial deployment of a new application.

app set: Used to modify the configuration or parameters of an existing application.

Hard Refresh: A command that bypasses the Argo CD cache to fetch the absolute latest state from Git and the Cluster.

Reconciliation/Diff: The process of identifying the exact mismatch between the Git "Source of Truth" and the Cluster's "Live State".

gRPC-web: A connectivity flag used to avoid connection drops when the CLI is operating behind a proxy or load balancer.

# --- 1. ACCOUNT & SESSION MANAGEMENT ---
# View CLI/Server versions and update the local password
argocd version
argocd account update-password
argocd account get-user-info

# Manage server contexts (list and switch between different Argo CD instances)
argocd context --list
argocd context <CONTEXT_NAME>

# --- 2. APPLICATION OPERATIONS ---
# List all apps and get specific details/manifests
argocd app list
argocd app get <APP_NAME>
argocd app manifest <APP_NAME>

# Detect drift (Diff) and Sync the application
argocd app diff <APP_NAME>
argocd app sync <APP_NAME>

# Force a sync for specific resources or perform a hard refresh
# argocd app sync <APP_NAME> --force --resource <KIND:NAME>
argocd app get <APP_NAME> --hard-refresh

# --- 3. CONFIGURATION CHANGES (APP SET) ---
# Modify an existing application's sync policy or parameters
argocd app set <APP_NAME> --sync-policy automated --self-heal --allow-empty

# --- 4. DEBUGGING & HISTORY ---
# View real-time logs for the entire application and check sync history
argocd app logs <APP_NAME>
argocd app history <APP_NAME>

# Revert to a previous deployment version based on History ID
# argocd app rollback <APP_NAME> <ID>

# --- 5. INFRASTRUCTURE & SETTINGS ---
# Manage clusters, repositories, and projects
argocd cluster list
argocd repo list
argocd proj create <PROJ_NAME> --description "Managed via CLI"

# --- 6. ADVANCED: TOKEN GENERATION ---
# Generate an API token for a specific service account (useful for automation)
# argocd account generate-token --account <ACCOUNT_NAME>

Summary of Operational Best Practices
The video emphasizes that the CLI is the primary way to perform Safe Rollbacks and Drift Detection. Commands like argocd app diff are safer than manual UI checks because they provide a line-by-line comparison of what will change before you hit sync. Additionally, using the CLI for ApplicationSet updates or project creation ensures that the configurations can be scripted and easily replicated.