#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-demo-eks}"
NAMESPACE="kube-system"
RELEASE_NAME="aws-load-balancer-controller"

for binary in aws helm kubectl; do
    if ! command -v "$binary" >/dev/null 2>&1; then
        echo "$binary is required but was not found in PATH."
        exit 1
    fi
done

echo "Attaching ElasticLoadBalancingFullAccess to eksWorkerNodeRole..."
aws iam attach-role-policy \
    --role-name eksWorkerNodeRole \
    --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks

echo "Installing AWS Load Balancer Controller..."
helm upgrade --install "$RELEASE_NAME" eks/aws-load-balancer-controller \
    -n "$NAMESPACE" \
    --set "clusterName=$CLUSTER_NAME" \
    --wait

kubectl rollout status deployment/$RELEASE_NAME -n "$NAMESPACE"
