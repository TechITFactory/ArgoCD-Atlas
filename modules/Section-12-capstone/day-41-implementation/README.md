# Day 45 — Capstone Implementation

It is time to translate your design into YAML. Follow this implementation checklist to build the Atlas Corp platform.

# --- IMPLEMENTATION CHECKLIST ---

### Phase 1: Platform Bootstrapping
- [ ] Spin up a local Kubernetes cluster (e.g., Kind, Minikube, or K3s).
- [ ] Install Argo CD using the High Availability manifests.
- [ ] Create a `platform-config` Git repository.
- [ ] Create an "App of Apps" `Application` that points to `platform-config` to manage Argo CD's own ConfigMaps and Secrets.

### Phase 2: Security & Tenancy
- [ ] In your `platform-config` repo, create three `AppProject` definitions: `backend-proj`, `frontend-proj`, `data-proj`.
- [ ] Configure the `argocd-rbac-cm` ConfigMap to map three distinct roles (e.g., `role:backend-dev`) to these projects.
- [ ] Install External Secrets Operator (ESO) and configure a `ClusterSecretStore`.

### Phase 3: Application Automation
- [ ] Create an `ApplicationSet` using the Git Generator (Directory matching). 
- [ ] Point the ApplicationSet to a `microservices/` folder in your Git repository.
- [ ] Configure the template so that if a developer pushes a new folder (e.g., `microservices/billing-api`), the ApplicationSet automatically creates an Argo CD Application deployed to the `backend-proj`.

### Phase 4: CI & Notifications
- [ ] Install the Argo CD Image Updater.
- [ ] Annotate one of your microservices to use the Image Updater with the `semver` strategy and Git Write-Back enabled.
- [ ] Install the Argo CD Notifications Catalog.
- [ ] Configure a mock Slack (or Email) service in `argocd-notifications-cm`.
- [ ] Add the `on-sync-succeeded` notification annotation to your `ApplicationSet` template.

# --- TESTING YOUR IMPLEMENTATION ---
Once you have written all the YAML, execute the ultimate GitOps test:
1. Delete your entire Argo CD namespace: `kubectl delete ns argocd`
2. Reinstall vanilla Argo CD.
3. Apply your single Bootstrapping Application.
4. Watch as the entire platform, the AppProjects, the RBAC, the ApplicationSets, and the microservices automatically rebuild themselves.

*If you can successfully complete this test, your platform is production-ready.*
