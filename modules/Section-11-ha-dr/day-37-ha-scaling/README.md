# Day 41 — High Availability (HA) & Sharding

Running Argo CD in production requires a High Availability (HA) setup to handle thousands of applications and survive node failures. The default Argo CD installation runs a single replica of each component, which is a single point of failure and a bottleneck at scale.

# --- 1. COMPONENT SCALING ---
To scale Argo CD, you must apply the official `ha` manifests instead of the standard ones:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml
```

This installation changes the architecture:
- **API Server & UI (`argocd-server`)**: Scaled to `> 1` replica. Fully stateless.
- **Repo Server (`argocd-repo-server`)**: Scaled to `> 1` replica. This component does the heavy lifting of cloning Git repos and running `kustomize/helm`. It is memory/CPU intensive.
- **Redis**: Replaced with **Redis HA** using Redis Sentinel (managed by HAProxy) to ensure the cache survives pod restarts.

# --- 2. CONTROLLER SHARDING ---
The `argocd-application-controller` is stateful. It maintains a connection to the Kubernetes API server of every cluster it manages. If you manage 50+ clusters or 2000+ applications, a single controller will run out of memory.

You must "shard" the controller to distribute the load across multiple replicas.

To enable sharding, edit the StatefulSet of the application controller:
1. Scale the StatefulSet replicas (e.g., to `3`).
2. Set the `ARGOCD_CONTROLLER_REPLICAS` environment variable to `3`.

```yaml
# Inside the argocd-application-controller StatefulSet
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: argocd-application-controller
        env:
        - name: ARGOCD_CONTROLLER_REPLICAS
          value: "3"
```

# --- 3. DYNAMIC CLUSTER DISTRIBUTION ---
By default, the controller assigns managed clusters to shards using a basic hash of the cluster's UUID. However, if Cluster A has 1000 apps and Cluster B has 2 apps, the load will be highly unbalanced.

Argo CD supports **Dynamic Cluster Distribution** (Round-Robin), which automatically balances clusters across shards based on the actual number of applications running on them.

Enable it in the `argocd-cmd-params-cm` ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  # Use dynamic balancing instead of legacy hashing
  controller.sharding.algorithm: "round-robin"
```

Operational Insight
The Repo Server is the most resource-hungry component in Argo CD. If your syncs are failing with `OOMKilled` or `rpc error: code = ResourceExhausted`, the Repo Server needs more memory, or you need to add more replicas. Conversely, the Application Controller is constrained by API rate limits. If the controller is struggling, you must shard it.
