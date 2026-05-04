#!/bin/bash
# ============================================================
# Manual setup script for EKS monitoring stack
# Run this once against your EKS cluster
# Prerequisites: kubectl, helm, aws cli configured
# ============================================================
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-my-eks-cluster}"
REGION="${REGION:-us-east-1}"

echo "==> Updating kubeconfig for cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "==> Applying dev and prod workloads"
kubectl apply -f k8s/dev/workload.yaml
kubectl apply -f k8s/prod/workload.yaml

echo "==> Adding Prometheus Helm repo"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "==> Installing kube-prometheus-stack in monitoring namespace"
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values k8s/monitoring/values.yaml \
  --wait

echo ""
echo "==> Waiting for Prometheus LoadBalancer IP..."
kubectl get svc -n monitoring kube-prometheus-stack-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
  kubectl get svc -n monitoring kube-prometheus-stack-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

echo ""
echo "==> Pods in monitoring namespace:"
kubectl get pods -n monitoring

echo ""
echo "==> Pods in dev namespace:"
kubectl get pods -n dev

echo ""
echo "==> Pods in prod namespace:"
kubectl get pods -n prod

echo ""
echo "==> DONE. Copy the Prometheus external address above."
echo "    Set it as TF_VAR_prometheus_url before running Terraform."
