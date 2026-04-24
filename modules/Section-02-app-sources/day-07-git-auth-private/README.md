Personal Access Token (PAT): A human-linked identity. Easy for testing but risky for production because it is tied to a specific user's account and lacks automated rotation.

SSH Keys: A common method with no expiration date. If leaked, they provide "forever access" until manually revoked, making them a security risk.

GitHub App: The recommended production method. It is decoupled from individual users, uses expiring JWT tokens for security, and allows fine-grained "read/write" permissions.

Installation ID: A unique ID generated when a GitHub App is installed on a specific organization or repository.

App ID: The unique identifier for the registered GitHub App itself.

# --- 1. PREPARE THE PRIVATE REPOSITORY SECRET (YAML) ---
# This secret tells Argo CD to use your GitHub App for authentication
cat <<EOF > github-app-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
spec:
  type: Opaque
  stringData:
    url: https://github.com/your-org/private-repo  # URL of your private repo
    githubAppID: "123456"                          # Your App ID from GitHub
    githubAppInstallationID: "78910"               # Your Installation ID from GitHub
    githubAppPrivateKey: |                         # Content of your .pem private key
      -----BEGIN RSA PRIVATE KEY-----
      ... (Insert Private Key Content) ...
      -----END RSA PRIVATE KEY-----
EOF

# Apply the secret to the cluster
kubectl apply -f github-app-secret.yaml

# --- 2. REGISTER REPOSITORY VIA CLI ---
# Log in to Argo CD first (ensure port-forward is running if local)
# argocd login localhost:8080

# Add the repository link to Argo CD
argocd repo add https://github.com/your-org/private-repo --username your-github-user

# --- 3. VERIFICATION ---
# Verify that the repository is now 'Successful' in the list
argocd repo list

The "Why" of GitHub Apps
The video highlights that unlike SSH or PAT, the GitHub App method is production-grade because it allows you to restrict access to only the specific repositories needed. It also avoids the "leaked key" disaster because the session tokens expire automatically, whereas an SSH key remains valid until someone manually deletes it.