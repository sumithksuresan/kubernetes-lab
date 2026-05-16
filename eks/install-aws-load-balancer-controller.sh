#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-demo-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="kube-system"
RELEASE_NAME="aws-load-balancer-controller"

for binary in aws helm kubectl terraform sed; do
    if ! command -v "$binary" >/dev/null 2>&1; then
        echo "$binary is required but was not found in PATH."
        exit 1
    fi
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)
aws_auth_template="$script_dir/aws-auth-cm.yaml"
nginx_manifest="$repo_dir/nginx-deployment.yaml"
node_instance_role=$(terraform -chdir="$script_dir" output -raw NodeInstanceRole)

if [[ -z "$node_instance_role" ]]; then
    echo "Terraform output NodeInstanceRole is empty. Run terraform apply first."
    exit 1
fi

if [[ ! -f "$aws_auth_template" ]]; then
    echo "Missing aws-auth template: $aws_auth_template"
    exit 1
fi

if [[ ! -f "$nginx_manifest" ]]; then
    echo "Missing nginx manifest: $nginx_manifest"
    exit 1
fi

echo "Updating kubeconfig context for ${CLUSTER_NAME}..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
echo "Applying aws-auth ConfigMap with NodeInstanceRole: ${node_instance_role}"
sed "s|rolearn: .*|rolearn: ${node_instance_role}|" "$aws_auth_template" | kubectl apply -f -

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks

echo "Installing AWS Load Balancer Controller..."
helm upgrade --install "$RELEASE_NAME" eks/aws-load-balancer-controller \
    -n "$NAMESPACE" \
    --set "clusterName=$CLUSTER_NAME" \
    --wait

kubectl rollout status deployment/$RELEASE_NAME -n "$NAMESPACE"


echo "Applying nginx deployment..."
kubectl apply -f "$nginx_manifest"
