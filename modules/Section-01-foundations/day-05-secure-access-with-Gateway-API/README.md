Gateway API: The official successor to Ingress, offering a more expressive and role-oriented way to manage cluster traffic.

GatewayClass: A cluster-scoped resource that defines the infrastructure provider (e.g., Envoy).

Gateway: A namespace-scoped resource that acts as the entry point, defining ports (443), protocols (HTTPS), and TLS certificates.

HTTPRoute: Defines the specific routing logic, such as hostnames (argocd.example.com) and which internal service to target.

TLS Termination: The practice of decrypting HTTPS traffic at the Gateway level so that internal traffic can flow via standard HTTP to the backend.

# --- 1. INSTALL GATEWAY API CRDs ---
# Native K8s needs these definitions to understand 'Gateway' and 'HTTPRoute'
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# --- 2. INSTALL ENVOY GATEWAY CONTROLLER ---
# Deploying the controller that will watch our Gateway resources
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.2.1 -n envoy-gateway-system --create-namespace

# --- 3. CONFIGURE TLS (SELF-SIGNED EXAMPLE) ---
# Create the secret used for HTTPS termination as discussed in the demo
# Note: Ensure you have your tls.crt and tls.key files ready
kubectl create secret tls argo-cd-tls -n argocd --cert=tls.crt --key=tls.key

# --- 4. DEFINE THE GATEWAY (The Infrastructure) ---
cat <<EOF > 01-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: argo-cd-gateway
  namespace: argocd
spec:
  gatewayClassName: envoy
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: argo-cd-tls
EOF
kubectl apply -f 01-gateway.yaml

# --- 5. DEFINE THE HTTPROUTE (The Routing Logic) ---
cat <<EOF > 02-http-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argo-cd-route
  namespace: argocd
spec:
  parentRefs:
  - name: argo-cd-gateway
  hostnames:
  - "argocd.example.com"
  rules:
  - backendRefs:
    - name: argocd-server
      port: 80
EOF
kubectl apply -f 02-http-route.yaml

# --- 6. ARGOCD CONFIGURATION PATCH ---
# Patching 'server.insecure' to true to allow the Gateway to handle the TLS
kubectl patch cm argocd-cmd-params-cm -n argocd -p '{"data": {"server.insecure": "true"}}'
kubectl rollout restart deployment argocd-server -n argocd

# --- 7. VERIFY & ACCESS ---
# Check the Gateway status and address
kubectl get gateway -n argocd

# For local testing, port-forward the generated Envoy service
# kubectl port-forward svc/envoy-argocd-gateway-https -n envoy-gateway-system 8443:443

Why the Gateway API?
The video highlights that unlike Ingress, which often relies on a "monolithic" configuration filled with proprietary annotations, the Gateway API provides a standardized, provider-agnostic way to manage traffic. It allows the Platform team to handle security (Gateways) while developers focus on application paths (Routes).