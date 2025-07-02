resource "null_resource" "kubeconfig" {
  depends_on = [scaleway_k8s_pool.default_pool]
  triggers = {
    host                   = scaleway_k8s_cluster.kapsule_cluster.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.kapsule_cluster.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.kapsule_cluster.kubeconfig[0].cluster_ca_certificate
    #client_certificate = scaleway_k8s_cluster.kapsule_cluster.kubeconfig[0].certificate
    #key = scaleway_k8s_cluster.k8s_cluster.kubeconfig[0].key
  }

  provisioner "local-exec" {
    environment = {
      HIDE_OUTPUT = var.hide # Workaround to hide local-exec output
    }
    command = <<-EOT
    cat<<EOF>kubeconfig.yaml
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: ${self.triggers.cluster_ca_certificate}
        server: ${self.triggers.host}
      name: ${scaleway_k8s_cluster.kapsule_cluster.name}
    contexts:
    - context:
        cluster: ${scaleway_k8s_cluster.kapsule_cluster.name}
        user: admin
      name: admin@${scaleway_k8s_cluster.kapsule_cluster.name}
    current-context: admin@${scaleway_k8s_cluster.kapsule_cluster.name}
    kind: Config
    preferences: {}
    users:
    - name: admin
      user:
        token: ${self.triggers.token}
    EOF
    EOT
  }
}
