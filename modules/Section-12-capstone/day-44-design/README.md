# Day 44 — Capstone Project Design

Welcome to the final section of the Argo CD Atlas! You have learned every major feature of Argo CD, from basic Sync Policies to advanced ApplicationSets, SSO RBAC, CI integration, and High Availability.

It is time to prove your knowledge. For the Capstone project, you are tasked with designing and implementing a production-ready Internal Developer Platform (IDP) from scratch.

# --- THE BUSINESS REQUIREMENTS ---
You have been hired as the Lead Platform Engineer for "Atlas Corp." They have three engineering teams: Backend, Frontend, and Data. They want a centralized Argo CD instance that manages deployments across three different Kubernetes clusters (Dev, Staging, Prod).

**Requirement 1: Architecture & HA**
- The Argo CD installation must be Highly Available.
- It must be configured using the "App of Apps" pattern (GitOps for GitOps).

**Requirement 2: Security & RBAC**
- You must create three separate `AppProjects` (Backend, Frontend, Data).
- Each project must be strictly isolated. The Frontend team cannot sync or delete Backend apps.
- All secrets must be managed securely using External Secrets Operator.

**Requirement 3: Automation (ApplicationSets)**
- Applications should not be created manually.
- You must design an `ApplicationSet` using the Git Generator (Directory matching) that automatically discovers new microservices added to the monorepo and deploys them to the correct cluster.

**Requirement 4: CI & Observability**
- When an app is deployed to Production, a notification must be sent to a mock Slack channel.
- The Image Updater must be configured to watch the container registry and automatically deploy new semantic versions to the Dev cluster (with Git Write-Back enabled).

# --- TODAY'S TASK: ARCHITECTURAL DIAGRAM ---
Before writing any YAML, you must design the system. 

1. Map out your Git repository structure. (Where do the ApplicationSets live? Where do the microservice manifests live?)
2. Map out the RBAC policies. (Who gets what role?)
3. Determine which components (Dex, Image Updater, Notifications) need to be enabled.

*Spend today reviewing the requirements and sketching out your GitOps file structure on a whiteboard or digital notepad.*
