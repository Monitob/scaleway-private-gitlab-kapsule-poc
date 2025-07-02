Scaleway Private GitLab & Kapsule Communication POC
This repository provides a Proof of Concept (POC) demonstrating secure, private communication between a self-hosted GitLab instance running on a Scaleway Instance and a Scaleway Kubernetes Kapsule cluster. Both services are configured to operate within a shared Scaleway Private Network (VPC), ensuring all core communication happens internally without public internet exposure.

The primary integration method showcased is the GitLab Agent for Kubernetes, which facilitates a robust and secure connection for CI/CD deployments and GitOps workflows.

🚀 Architecture Overview
``` text
+---------------------------+       +-----------------------------------+
|      Scaleway Project     |       |           Scaleway Kapsule        |
|                           |       |          Kubernetes Cluster       |
| +-----------------------+ |       | +-------------------------------+ |
| | Private Network (VPC) | |       | | Kapsule Nodes (Private IPs)   | |
| | (e.g., 10.0.0.0/24)   | |       | |                               | |
| |                       | |       | |  +--------------------------+ | |
| | +-------------------+ |<--------->|  | gitlab-agent (agentk Pod)| | |
| | | GitLab Instance   | |       | |  +--------------------------+ | |
| | | (Private IP)      | |       | |                               | |
| | |                   | |       | +-------------------------------+ |
| | |  +-------------+  | |       +-----------------------------------+
| | |  | GitLab KAS  |<----+
| | |  | (Port 8150) |  | |       (Outbound connection initiated by agentk)
| | |  +-------------+  | |
| | +-------------------+ |
| |           ^           |
| |           | (Outbound) |
| |           v           |
| | +-------------------+ |
| | | Public Gateway    | |
| | | (Public IP)       | |
| | +-------------------+ |
| +-----------------------+ |
+---------------------------+
       ^
       | (SSH/HTTPS for initial setup)
       v
  Your Local Machine
```
✨ Features Demonstrated
Private Network Setup: Both GitLab and Kapsule reside on a shared Scaleway Private Network.

Outbound Internet Access for Private Instance: Use of a Scaleway Public Gateway to provide internet access for the GitLab instance (e.g., for apt updates, GitLab package downloads).

GitLab Agent for Kubernetes: Secure, bidirectional communication between private GitLab and Kapsule.

GitOps Workflow (Basic): Deploying a simple NGINX application to Kapsule via changes in the GitLab repository, managed by the GitLab Agent.

📋 Prerequisites
Before you begin, ensure you have the following:

Scaleway Account: With sufficient quotas for Instances, Kubernetes Kapsule, and VPC.

Scaleway API Key: Configured as environment variables (SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID, SCW_DEFAULT_REGION).

Terraform: Install Terraform (v1.0+ recommended).

Scaleway CLI: Install Scaleway CLI for kubeconfig retrieval.

Helm: Install Helm (v3.0+ recommended).

SSH Client: For connecting to the GitLab instance.

your_strong_password_for_gitlab_root: Choose a strong password for the GitLab root user in terraform/main.tf before deployment.

🚀 Setup Instructions
Follow these steps sequentially to set up the POC environment.

Step 1: Deploy Scaleway Infrastructure with Terraform
Clone this repository:

git clone <this-repo-url>
cd <this-repo-name>

Navigate to Terraform directory:

cd terraform

Initialize Terraform:

terraform init

Review the plan:

terraform plan

Important: Review the output carefully. Note the gitlab_instance_private_ip and gitlab_ssh_command outputs.

Apply the configuration:

terraform apply

Type yes when prompted to confirm the creation of resources.

Wait Time: This step will take some time (10-20 minutes) as Scaleway provisions resources and cloud-init installs GitLab.

Step 2: Verify GitLab Instance and Get Agent Token
Get GitLab Instance Public Gateway IP:
From the terraform apply output, copy the gitlab_ssh_command. It will look like ssh root@<PUBLIC_GATEWAY_IP>.

SSH into the GitLab Instance:

ssh root@<PUBLIC_GATEWAY_IP> or better use the bastion

ssh -J bastion@<PUBLIC_GATEWAY_IP>:61000 root@<resource-name>.<pvn-name>.internal

If you get "Network is unreachable" or "Connection refused", review the "Troubleshooting Outbound Connectivity" section below.

Verify GitLab Services:
Once SSHed in, run:

sudo gitlab-ctl status

All critical services (like puma, nginx, postgresql, gitlab-kas) should show ok: run. If not, check sudo gitlab-ctl tail for errors. You might need to wait a few more minutes or run sudo gitlab-ctl reconfigure.

Access GitLab UI:
Open a web browser and navigate to http://<PUBLIC_GATEWAY_IP>.

Log in as root with the password you set in terraform/main.tf (your_strong_password_for_gitlab_root).

Create GitLab Agent Configuration Project:

In GitLab, create a new blank project (e.g., my-group/kapsule-agent-config). This project will host the agent's configuration.

Register the GitLab Agent:

Navigate to your new project (my-group/kapsule-agent-config).

Go to Operate > Kubernetes clusters.

Click the Agent tab.

Click Connect a cluster (agent).

Enter a Name of new agent (e.g., my-kapsule-poc-agent). Ensure this matches the directory name under .gitlab/agents/ in this repo.

Click Create and register.

CRITICAL: GitLab will display an "Agent access token". COPY THIS TOKEN IMMEDIATELY AND SECURELY. You will not see it again.

GitLab will also provide a Helm command. Note the --set token='...' and --set kas.url='...' parts.

Step 3: Deploy GitLab Agent to Kapsule Cluster
Get Kapsule Kubeconfig:
From your local machine (not SSHed into GitLab instance), use the Terraform output:

cd ../terraform # Go back to terraform directory if you left it
terraform output -raw kapsule_kubeconfig_command > get_kubeconfig.sh
chmod +x get_kubeconfig.sh
./get_kubeconfig.sh # This will save kubeconfig.yaml in your current directory
export KUBECONFIG=$(pwd)/kubeconfig.yaml

Get GitLab Instance Private IP:

terraform output gitlab_instance_private_ip

Copy this IP. Let's assume it's 10.0.0.10 for this example.

Navigate to Kubernetes Agent directory:

cd ../kubernetes/gitlab-agent

Prepare install-agent.sh:
Edit the install-agent.sh script:

Replace <YOUR_COPIED_AGENT_TOKEN> with the token you copied from GitLab UI.

Replace <YOUR_GITLAB_PRIVATE_IP> with the private IP you just copied (e.g., 10.0.0.10).

Ensure my-kapsule-poc-agent matches the agent name you chose.

#!/bin/bash

# IMPORTANT: Replace <YOUR_COPIED_AGENT_TOKEN> with the token you copied from GitLab UI.
# IMPORTANT: Replace <YOUR_GITLAB_PRIVATE_IP> with the output 'gitlab_instance_private_ip' from Terraform.
# Ensure 'my-kapsule-poc-agent' matches the agent name you chose in GitLab.

AGENT_NAME="my-kapsule-poc-agent"
AGENT_TOKEN="<YOUR_COPIED_AGENT_TOKEN>"
GITLAB_PRIVATE_IP="<YOUR_GITLAB_PRIVATE_IP>" # e.g., 10.0.0.10
KAS_URL="grpc://${GITLAB_PRIVATE_IP}:8150" # Using gRPC on private IP

echo "Adding GitLab Helm repository..."
helm repo add gitlab https://charts.gitlab.io || { echo "Failed to add Helm repo"; exit 1; }
helm repo update || { echo "Failed to update Helm repo"; exit 1; }

echo "Installing/Upgrading GitLab Agent (${AGENT_NAME}) to Kapsule cluster..."
helm upgrade --install "${AGENT_NAME}" gitlab/gitlab-agent \
  --namespace gitlab-agent \
  --create-namespace \
  --set token="${AGENT_TOKEN}" \
  --set kas.url="${KAS_URL}" \
  --set rbac.create=true \
  --set rbac.clusterWide=true # For POC, grants cluster-admin. Restrict in production! \
  || { echo "Failed to install/upgrade GitLab Agent"; exit 1; }

echo "GitLab Agent deployment initiated. Check status with 'kubectl get pods -n gitlab-agent'"

Run the installation script:

chmod +x install-agent.sh
./install-agent.sh

✅ Verification Steps
1. Verify GitLab Agent Connection in GitLab UI
Log in to your private GitLab instance.

Navigate to your agent's configuration project (Operate > Kubernetes clusters).

Go to the Agent tab.

Your agent (my-kapsule-poc-agent) should now show a green "Connected" status. This confirms the private communication channel is active.

2. Verify Network Connectivity from Kapsule to GitLab (Optional, but good for diagnostics)
Connect to a test pod in Kapsule:

kubectl run -it --rm --restart=Never test-pod --image=ubuntu:latest -- bash

Install tools inside the pod:

apt update && apt install -y iputils-ping curl net-tools

Ping GitLab Instance Private IP:

ping <YOUR_GITLAB_PRIVATE_IP> # e.g., ping 10.0.0.10

You should see successful pings.

Curl GitLab Web UI (HTTP):

curl -v http://<YOUR_GITLAB_PRIVATE_IP> # e.g., curl -v http://10.0.0.10

You should get an HTTP response (likely a 302 redirect or HTML).

Curl GitLab KAS API (gRPC port):

curl -v telnet://<YOUR_GITLAB_PRIVATE_IP>:8150 # e.g., curl -v telnet://10.0.0.10:8150

This should show a successful connection, even if the protocol is not understood by curl.

Exit the pod:

exit

3. Verify Network Connectivity from GitLab Instance to Kapsule API Server (Optional)
SSH into your GitLab instance:

ssh root@<PUBLIC_GATEWAY_IP>

Get Kapsule API Server Private IP:
On your local machine, run grep 'server:' kubeconfig.yaml to find the Kapsule API server's private IP (e.g., 10.0.0.20).

Test connection from GitLab instance:

# Install netcat if not present: apt update && apt install -y netcat-traditional
nc -vz <KAPSULE_API_PRIVATE_IP> 6443 # e.g., nc -vz 10.0.0.20 6443

You should see Connection to <KAPSULE_API_PRIVATE_IP> 6443 port [tcp/*] succeeded!.

curl -vk https://<KAPSULE_API_PRIVATE_IP>:6443/ # e.g., curl -vk https://10.0.0.20:6443/

You should get a response (e.g., 401 Unauthorized), indicating the API server is reachable.

4. Demonstrate GitOps Workflow
Configure GitLab Agent for Manifest Sync:

In your GitLab project (my-group/kapsule-agent-config), create the file .gitlab/agents/my-kapsule-poc-agent/config.yaml.

Add the following content to config.yaml:

# .gitlab/agents/my-kapsule-poc-agent/config.yaml
gitops:
  manifest_projects:
    - id: <your-gitlab-group>/kapsule-agent-config # e.g., my-group/kapsule-agent-config
      paths:
        - glob: '/kubernetes/gitops-manifests/*.yaml' # Agent will sync YAML files from this path

Important: Replace <your-gitlab-group>/kapsule-agent-config with the actual path to your GitLab project.

Create a Sample Manifest:

Create the directory kubernetes/gitops-manifests/ in your local repository.

Inside kubernetes/gitops-manifests/, create nginx-deployment.yaml with the following content:

# kubernetes/gitops-manifests/nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-example
  namespace: default
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-example-service
  namespace: default
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP

Commit and Push to GitLab:

git add .gitlab/agents/my-kapsule-poc-agent/config.yaml kubernetes/gitops-manifests/nginx-deployment.yaml
git commit -m "Add GitLab Agent config and NGINX manifest for GitOps demo"
git push origin main

Verify Deployment in Kapsule:
The GitLab Agent in your Kapsule cluster should detect the changes and deploy the NGINX application.

kubectl get deployments -n default
kubectl get services -n default

You should see nginx-example deployment and nginx-example-service running.

🧹 Cleanup
To avoid incurring ongoing costs, remember to destroy the resources after you are done with the POC.

Delete GitLab Agent from Kapsule:

helm uninstall my-kapsule-poc-agent --namespace gitlab-agent
kubectl delete namespace gitlab-agent

Destroy Scaleway Infrastructure with Terraform:

cd terraform
terraform destroy

Type yes when prompted to confirm the deletion of resources.

⚠️ Important Notes & Security Considerations
Passwords: The cloud-init script sets a simple root password for GitLab for POC purposes. NEVER use this in production. Implement a secure secret management solution.

RBAC Permissions: For this POC, the GitLab Agent is granted cluster-admin permissions (rbac.clusterWide=true). In a production environment, restrict these permissions to the absolute minimum necessary for your deployments (e.g., specific namespaces, specific resource types).

TLS for KAS: For production, you should configure TLS (HTTPS) for the GitLab Agent Server (KAS) on your private GitLab instance and ensure agentk trusts its certificate. This POC uses plain gRPC (grpc://) for simplicity within the private network.

Scaleway Security Groups: Always review and tighten security group rules beyond what's shown in this POC. Ensure only necessary ports are open from allowed sources.

GitLab Runner: This POC focuses on the GitLab Agent. If you need GitLab CI/CD pipelines to run jobs that interact with the cluster directly (e.g., building Docker images), you'd typically deploy GitLab Runners on Kapsule, which would also communicate over the private network.
