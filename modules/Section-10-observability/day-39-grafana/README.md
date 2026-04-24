# Day 39 — Grafana Dashboards for Argo CD

Raw Prometheus metrics are powerful for alerting, but difficult to read. Visualizing those metrics using Grafana provides a "single pane of glass" for the health of your entire GitOps infrastructure.

The Argo CD open-source community provides an official, community-maintained Grafana dashboard that automatically visualizes the metrics scraped from the Application Controller, Repo Server, and API Server.

# --- 1. IMPORTING THE OFFICIAL DASHBOARD ---
You do not need to build your own dashboard. You can import the official Argo CD dashboard directly into your Grafana instance.

1. Open your Grafana UI.
2. Navigate to **Dashboards -> Import**.
3. Enter the dashboard ID: `14191` (or import the JSON from the `argoproj/argo-cd` GitHub repository).
4. Select your Prometheus data source.

# --- 2. WHAT THE DASHBOARD SHOWS ---
The official dashboard is divided into critical sections:

**1. Application Status (High-Level)**
- A pie chart showing the Sync Status of all apps (Synced vs OutOfSync).
- A pie chart showing the Health Status of all apps (Healthy, Progressing, Degraded).
- A time-series graph showing the total number of managed applications over time.

**2. Controller Performance (Deep Dive)**
- **Reconciliation Queue Size:** How many applications are waiting to be checked against Git. If this number climbs, your controller is overloaded.
- **Reconciliation Time:** How long it takes to process an application. If this spikes, you likely have network latency talking to the destination Kubernetes clusters.

**3. Repository Performance (Git/Helm)**
- **Git Fetch Duration:** How long it takes to run `git pull`. Spikes here indicate issues with GitHub/GitLab.
- **Manifest Generation Time:** How long it takes `kustomize build` or `helm template` to run. Complex Helm charts with many dependencies will drive this metric up.

Operational Insight
Put this Grafana dashboard on a TV monitor in your engineering space. If the "Reconciliation Queue Size" spikes, it usually means someone pushed a massive monorepo commit and Argo CD is struggling to process hundreds of apps at once. If "Git Fetch Duration" spikes, you know immediately the problem is with your Git provider, not Argo CD. The dashboard cuts debugging time from hours to seconds.
