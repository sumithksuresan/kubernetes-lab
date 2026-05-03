#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-demo-eks}"
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
CHART_VERSION="${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION:-1.14.0}"
RELEASE_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"

if [[ -z "$AWS_REGION" ]]; then
    AWS_REGION=$(aws configure get region)
fi

if [[ -z "$AWS_REGION" ]]; then
    echo "AWS region is not set. Export AWS_REGION or configure a default AWS region."
    exit 1
fi

for binary in aws kubectl helm terraform; do
    if ! command -v "$binary" >/dev/null 2>&1; then
        echo "$binary is required but was not found in PATH."
        exit 1
    fi
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$script_dir"

ROLE_ARN="${AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN:-$(terraform output -raw LoadBalancerControllerRoleArn)}"
VPC_ID="${VPC_ID:-$(terraform output -raw VpcId)}"

aws eks update-kubeconfig \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION"

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks

helm upgrade --install "$RELEASE_NAME" eks/aws-load-balancer-controller \
    --namespace "$NAMESPACE" \
    --set "clusterName=$CLUSTER_NAME" \
    --set "region=$AWS_REGION" \
    --set "vpcId=$VPC_ID" \
    --set "serviceAccount.create=true" \
    --set "serviceAccount.name=$SERVICE_ACCOUNT_NAME" \
    --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$ROLE_ARN" \
    --version "$CHART_VERSION" \
    --wait

kubectl rollout status deployment/$RELEASE_NAME -n "$NAMESPACE"
kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"