locals {
  kind_config_path    = "/tmp/kind-config-${var.name}.yaml"
  kubeconfig_raw_path = "/tmp/kubeconfig-${var.name}-raw.yaml"
  container_name      = "${var.name}-control-plane"

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
      set -e

      # Delete stale cluster from previous failed runs
      kind delete cluster --name ${var.name} 2>/dev/null || true

      # Create cluster — kind may report a port-detection error on macOS Docker Desktop
      # after successfully creating the container, so we ignore the exit code and verify manually.
      kind create cluster \
        --name ${var.name} \
        --config ${local_file.kind_config.filename} \
        --wait 120s 2>&1 || true

      # Verify the cluster is actually ready
      ELAPSED=0
      until docker exec ${local.container_name} kubectl get nodes --request-timeout=5s 2>/dev/null | grep -q "Ready"; do
        if [ "$ELAPSED" -ge 120 ]; then
          echo "ERROR: kind cluster did not become ready within 120 seconds" >&2
          exit 1
        fi
        sleep 5
        ELAPSED=$((ELAPSED + 5))
      done
      echo "Cluster ${var.name} is ready."

      # If running inside a Docker container (Jenkins), connect to the kind network
      # so the Kubernetes API is reachable via the container IP.
      if [ -f /.dockerenv ]; then
        SELF=$(cat /proc/self/cgroup 2>/dev/null | grep -oP '(?<=/docker/)[a-f0-9]{12}' | head -1 \
               || hostname)
        docker network connect kind "$SELF" 2>/dev/null || \
          docker network connect kind jenkins 2>/dev/null || true
        CLUSTER_IP=$(docker inspect ${local.container_name} \
          --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
      else
        CLUSTER_IP="127.0.0.1"
        # When running on the host (not inside Docker), kind maps the API server
        # to a random host port — use that instead of the container-internal 6443.
        API_PORT=$(docker inspect ${local.container_name} \
          --format '{{(index (index .NetworkSettings.Ports "6443/tcp") 0).HostPort}}')
      fi
      API_PORT=$${API_PORT:-6443}

      # Get kubeconfig from inside the container and point server at reachable IP:port
      docker exec ${local.container_name} cat /etc/kubernetes/admin.conf \
        | sed "s|server: https://[^:]*:6443|server: https://$${CLUSTER_IP}:$${API_PORT}|g" \
        > ${local.kubeconfig_raw_path}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kind delete cluster --name ${self.triggers.name} 2>/dev/null || true
      if [ -f /.dockerenv ]; then
        SELF=$(cat /proc/self/cgroup 2>/dev/null | grep -oP '(?<=/docker/)[a-f0-9]{12}' | head -1 \
               || hostname)
        docker network disconnect kind "$SELF" 2>/dev/null || \
          docker network disconnect kind jenkins 2>/dev/null || true
      fi
    EOT
  }

  depends_on = [local_file.kind_config]
}

data "local_file" "kubeconfig_raw" {
  filename   = local.kubeconfig_raw_path
  depends_on = [null_resource.cluster]
}

locals {
  kube             = yamldecode(data.local_file.kubeconfig_raw.content)
  endpoint         = local.kube.clusters[0].cluster.server
  kubeconfig_fixed = data.local_file.kubeconfig_raw.content
}

resource "local_file" "kubeconfig" {
  content         = local.kubeconfig_fixed
  filename        = "${path.root}/kubeconfig-${var.name}.yaml"
  file_permission = "0600"
  depends_on      = [null_resource.cluster]
}
