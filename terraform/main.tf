# Configure the Scaleway provider
provider "scaleway" {
  # You can specify your project ID here, or let it use the default
  # project_id = "your-scaleway-project-id"
  region = "fr-par" # Or your preferred region (e.g., nl-ams, waw-1)
}

# --- Shared Private Network (VPC) ---
resource "scaleway_vpc_private_network" "gitlab_kapsule_private_network" {
  name   = "gitlab-kapsule-private-network-poc"
  region = "fr-par" # Must be in the same region as your instances/cluster
}

# --- Public Gateway for GitLab Instance's Outbound Access ---
# This is needed because the GitLab instance will have no public IP
# but needs internet access for initial setup (apt, gitlab packages)
resource "scaleway_vpc_public_gateway_ip" "gitlab_gateway_ip" {
  zone = "fr-par-1" # Choose an availability zone in your region
}

resource "scaleway_vpc_public_gateway" "gitlab_gateway" {
  name            = "gitlab-outbound-gateway"
  type            = "VPC-GW-S" # Small gateway type, adjust as needed
  ip_id           = scaleway_vpc_public_gateway_ip.gitlab_gateway_ip.id
  bastion_enabled = true
  zone            = "fr-par-1"
}

resource "scaleway_vpc_gateway_network" "gitlab_gateway_network_attachment" {
  gateway_id         = scaleway_vpc_public_gateway.gitlab_gateway.id
  private_network_id = scaleway_vpc_private_network.gitlab_kapsule_private_network.id
  # DHCP is usually enabled by default for private networks with gateways
  ipam_config {
    push_default_route = true
    #ipam_id = null # Let Scaleway manage IPAM
  }
  zone = "fr-par-1"
}

# --- Data source to read cloud-init script from an external file ---
data "local_file" "gitlab_cloud_init" {
  filename = "${path.module}/cloud-init-gitlab.yaml"
}

# --- Scaleway Instance for Private GitLab ---
resource "scaleway_instance_server" "gitlab_instance" {
  name  = "private-gitlab-poc"
  type  = "DEV1-S"       # Development instance type, adjust as needed
  image = "ubuntu_jammy" # Ubuntu LTS recommended for GitLab Omnibus
  zone  = "fr-par-1"
  # No public_ip block here, as it's a private instance

  # Attach to the private network
  private_network {
    pn_id = scaleway_vpc_private_network.gitlab_kapsule_private_network.id
    # Let Scaleway assign a private IP via DHCP
  }

  # Cloud-init script to install GitLab and configure KAS for private access
  # Cloud-init script is now read from an external file
  user_data = {
    "cloud-init" = data.local_file.gitlab_cloud_init.content
  }
}

# --- Scaleway Kubernetes Kapsule Cluster ---
resource "scaleway_k8s_cluster" "kapsule_cluster" {
  name                        = "private-kapsule-poc"
  version                     = "1.32.3" # Or a recent stable version supported by Scaleway
  region                      = "fr-par"
  cni                         = "cilium" # Good for network policies
  private_network_id          = scaleway_vpc_private_network.gitlab_kapsule_private_network.id
  delete_additional_resources = true
}

resource "scaleway_k8s_pool" "default_pool" {
  cluster_id = scaleway_k8s_cluster.kapsule_cluster.id
  name       = "default-pool"
  node_type  = "DEV1-M" # Development node type, adjust as needed
  size       = 1        # Smallest size for POC
  zone       = "fr-par-1"
  # Private network attachment is inherited from the cluster
}

# --- DataSource ---

