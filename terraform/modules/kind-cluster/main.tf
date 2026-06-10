locals {
  kind_config_path    = "/tmp/kind-config-${var.name}.yaml"
  kubeconfig_raw_path = "/tmp/kubeconfig-${var.name}-raw.yaml"

  kind_config = yamlencode({
    kind       = "Cluster"
    apiVersion = "kind.x-k8s.io/v1alpha4"
    nodes = [{
      role  = "control-plane"
      image = var.node_image
      extraPortMappings = [
        for pm in var.extra_port_mappings : {
          containerPort = pm.container_port
          hostPort      = pm.host_port
          protocol      = pm.protocol
        }
      ]
    }]
  })
}

resource "local_file" "kind_config" {
  content  = local.kind_config
  filename = local.kind_config_path
}

resource "null_resource" "cluster" {
  triggers = {
    name       = var.name
    node_image = var.node_image
    config     = sha256(local.kind_config)
  }

  provisioner "local-exec" {
    command = <<-EOT
      kind create cluster \
        --name ${var.name} \
        --config ${local_file.kind_config.filename} \
        --wait 120s
      kind get kubeconfig --name ${var.name} > ${local.kubeconfig_raw_path}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name ${self.triggers.name} 2>/dev/null || true"
  }

  depends_on = [local_file.kind_config]
}

data "local_file" "kubeconfig_raw" {
  filename   = local.kubeconfig_raw_path
  depends_on = [null_resource.cluster]
}

locals {
  kube             = yamldecode(data.local_file.kubeconfig_raw.content)
  endpoint         = replace(local.kube.clusters[0].cluster.server, "127.0.0.1", "host.docker.internal")
  kubeconfig_fixed = replace(data.local_file.kubeconfig_raw.content, "127.0.0.1", "host.docker.internal")
}

resource "local_file" "kubeconfig" {
  content         = local.kubeconfig_fixed
  filename        = "${path.root}/kubeconfig-${var.name}.yaml"
  file_permission = "0600"
  depends_on      = [null_resource.cluster]
}
