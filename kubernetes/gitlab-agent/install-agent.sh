    # IMPORTANT: Replace <YOUR_COPIED_AGENT_TOKEN> with the token you copied from GitLab UI.
    # IMPORTANT: Replace <YOUR_GITLAB_PRIVATE_IP> with the output 'gitlab_instance_private_ip' from Terraform.

    helm upgrade --install my-kapsule-poc-agent gitlab/gitlab-agent \
      --namespace gitlab-agent \
      --create-namespace \
      --set token='<YOUR_COPIED_AGENT_TOKEN>' \
      --set kas.url='grpc://<YOUR_GITLAB_PRIVATE_IP>:8150' \
      --set rbac.create=true \
      --set rbac.clusterWide=true # For POC, grants cluster-admin to agentk. Restrict in production!
    
