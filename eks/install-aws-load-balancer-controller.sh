#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-demo-eks}"
NAMESPACE="kube-system"
RELEASE_NAME="aws-load-balancer-controller"
POLICY_NAME="${LOAD_BALANCER_POLICY_NAME:-eksPolicy}"
ROLE_NAME="${LOAD_BALANCER_ROLE_NAME:-eksWorkerNodeRole}"

for binary in aws helm kubectl; do
    if ! command -v "$binary" >/dev/null 2>&1; then
        echo "$binary is required but was not found in PATH."
        exit 1
    fi
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
account_id=$(aws sts get-caller-identity --query Account --output text)
policy_arn="arn:aws:iam::${account_id}:policy/${POLICY_NAME}"

if ! aws iam get-policy --policy-arn "$policy_arn" >/dev/null 2>&1; then
    echo "Creating ${POLICY_NAME} for AWS Load Balancer Controller access..."
    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "file://${script_dir}/../iam_policy.json" >/dev/null
fi

echo "Attaching ${POLICY_NAME} to ${ROLE_NAME}..."
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$policy_arn"

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks

echo "Installing AWS Load Balancer Controller..."
helm upgrade --install "$RELEASE_NAME" eks/aws-load-balancer-controller \
    -n "$NAMESPACE" \
    --set "clusterName=$CLUSTER_NAME" \
    --wait

kubectl rollout status deployment/$RELEASE_NAME -n "$NAMESPACE"
