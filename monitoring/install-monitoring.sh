#!/usr/bin/env bash
#
# install-monitoring.sh
#
# Installs kube-prometheus-stack (Prometheus, Alertmanager, Grafana) on the
# dsb-devsecops-cluster EKS cluster via Helm, plus the app-specific
# ServiceMonitor and PrometheusRule alerting resources.
#
# This is intentionally Helm/kubectl only -- the EKS cluster itself is
# provisioned by the Terraform Cloud "dsb-aws-devsecops-eks-cluster"
# workspace, and monitoring resources are deliberately kept out of Terraform
# so they can be iterated on independently of infrastructure applies.
#
# Usage:
#   ./monitoring/install-monitoring.sh
#
# Requirements:
#   - helm >= 3.12
#   - kubectl configured against the target cluster (see README "Verify
#     Runtime" section for the aws eks update-kubeconfig command)
#   - EBS CSI driver installed on the cluster (required for gp3 PVCs used by
#     Prometheus/Grafana persistence in values.yaml)

set -euo pipefail

# --- Configurable values (override via environment variables) --------------
NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
RELEASE_NAME="${MONITORING_RELEASE_NAME:-kube-prometheus-stack}"
CHART_REPO_NAME="${MONITORING_REPO_NAME:-prometheus-community}"
CHART_REPO_URL="${MONITORING_REPO_URL:-https://prometheus-community.github.io/helm-charts}"
CHART_NAME="${CHART_REPO_NAME}/kube-prometheus-stack"
CHART_VERSION="${MONITORING_CHART_VERSION:-}" # empty = latest
VALUES_FILE="$(dirname "$0")/values.yaml"

echo "==> Adding/updating Helm repo: ${CHART_REPO_NAME}"
helm repo add "${CHART_REPO_NAME}" "${CHART_REPO_URL}" >/dev/null 2>&1 || true
helm repo update "${CHART_REPO_NAME}"

echo "==> Ensuring namespace '${NAMESPACE}' exists"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

# Real credentials go in a gitignored monitoring/remote-write-secret.local.yaml
# (see .gitignore "monitoring/*.local.yaml"); the committed *.yaml only has
# placeholders, so it's used as a fallback when no local override exists.
REMOTE_WRITE_SECRET_FILE="$(dirname "$0")/remote-write-secret.yaml"
if [[ -f "$(dirname "$0")/remote-write-secret.local.yaml" ]]; then
  REMOTE_WRITE_SECRET_FILE="$(dirname "$0")/remote-write-secret.local.yaml"
fi
echo "==> Applying Grafana Cloud remote_write credentials Secret (${REMOTE_WRITE_SECRET_FILE})"
kubectl apply -f "${REMOTE_WRITE_SECRET_FILE}"

echo "==> Installing/upgrading ${RELEASE_NAME} in namespace ${NAMESPACE}"
HELM_VERSION_ARG=()
if [[ -n "${CHART_VERSION}" ]]; then
  HELM_VERSION_ARG=(--version "${CHART_VERSION}")
fi

helm upgrade --install "${RELEASE_NAME}" "${CHART_NAME}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 10m \
  "${HELM_VERSION_ARG[@]}"

echo "==> Applying application ServiceMonitor"
kubectl apply -f "$(dirname "$0")/servicemonitor.yaml"

echo "==> Applying alerting rules and Alertmanager config"
kubectl apply -f "$(dirname "$0")/alerts/prometheus-rules.yaml"
kubectl apply -f "$(dirname "$0")/alerts/alertmanager-config.yaml"

echo "==> Done. Useful commands:"
echo "    kubectl -n ${NAMESPACE} get pods"
echo "    kubectl -n ${NAMESPACE} port-forward svc/${RELEASE_NAME}-grafana 3000:80"
echo "    kubectl -n ${NAMESPACE} port-forward svc/${RELEASE_NAME}-kube-prom-prometheus 9090:9090"
