# --- Outputs ---
output "gitlab_instance_private_ip" {
  description = "The private IP address of the GitLab instance within the VPC."
  value       = scaleway_instance_server.gitlab_instance.private_ips[0].address
}

output "kapsule_cluster_id" {
  description = "The ID of the Kapsule cluster."
  value       = scaleway_k8s_cluster.kapsule_cluster.id
}

output "gitlab_ssh_command" {
  description = "SSH command to connect to the GitLab instance via the Public Gateway (if SSH access is allowed on gateway/instance security groups)."
  value       = "ssh -J bastion@${scaleway_vpc_public_gateway_ip.gitlab_gateway_ip.address}:61000 root@${scaleway_instance_server.gitlab_instance.name}.${scaleway_vpc_private_network.gitlab_kapsule_private_network.name}.internal"
}

