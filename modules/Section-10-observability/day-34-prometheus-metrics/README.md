# Day 38 — Prometheus Metrics in Argo CD

Argo CD exposes rich, Prometheus-formatted metrics by default. These metrics provide critical observability into the health of your GitOps pipelines, the performance of the Argo CD controllers, and the sync status of all your applications.

# --- 1. THE METRICS ENDPOINTS ---
Argo CD exposes metrics on three different components, each on a different port:

1. **Application Controller Metrics (Port 8082):**
   - Tracks the number of Applications, their health, and sync status.
   - Example metric: `argocd_app_info` (labels include project, namespace, health status).
2. **API Server Metrics (Port 8083):**
   - Tracks incoming API and UI requests.
   - Example metric: `argocd_api_request_duration_seconds`.
3. **Repo Server Metrics (Port 8084):**
   - Tracks Git repository operations, fetch times, and cache hits.
   - Example metric: `argocd_repo_pending_request_total`.

# --- 2. CONFIGURING PROMETHEUS SCRAPING ---
If you installed Argo CD using the official Helm chart or manifests, the metrics ports are already exposed on the Kubernetes Services.

If you are using the Prometheus Operator, you can create a `ServiceMonitor` to automatically scrape these endpoints:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  namespaceSelector:
    matchNames:
      - argocd
  endpoints:
    - port: metrics # Application Controller
    - port: server-metrics # API Server
    - port: repo-server-metrics # Repo Server
```

# --- 3. KEY METRICS TO ALERT ON ---
When building alerts, focus on these critical indicators:

- `argocd_app_sync_status`: Alert if an application goes `OutOfSync` for too long.
- `argocd_app_health_status`: Alert if an application becomes `Degraded`.
- `argocd_redis_request_duration_seconds`: High latency here means your Repo Server is struggling to render manifests.
- `argocd_repo_pending_request_total`: A high number of pending requests means Argo CD cannot clone from your Git provider fast enough (rate limiting or network issues).

Operational Insight
While Argo CD Notifications (Section 9) is great for pinging developers when their specific app fails, Prometheus metrics are for the platform engineers. You use Prometheus to monitor the health of Argo CD *itself*. If the `argocd-repo-server` is failing to fetch from Git, no one's apps will sync. That's a platform emergency, and Prometheus is what catches it.
