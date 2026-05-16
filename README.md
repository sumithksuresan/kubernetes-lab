# Kubernetes Lab on KodeKloud AWS Playground

This lab deploys an Amazon EKS cluster in the KodeKloud AWS Playground, installs the AWS Load Balancer Controller, applies worker-node authentication, and deploys a sample NGINX application behind an AWS load balancer.

The lab is designed for the KodeKloud AWS Playground:

https://kodekloud.com/cloud-playgrounds/aws

KodeKloud playground accounts for this lab should use the `us-east-1` region.

## Quick Command Summary

Run these commands in order from a fresh KodeKloud AWS Playground terminal:

```bash
git clone https://github.com/sumithksuresan/kubernetes-lab.git
cd kubernetes-lab/eks
aws configure
source ./check-environment.sh
terraform init
terraform plan
terraform apply
./install-aws-load-balancer-controller.sh
kubectl get svc nginx-service
```

The automation script `./install-aws-load-balancer-controller.sh` runs after `terraform apply`. It updates the kubeconfig context, reads `NodeInstanceRole` from Terraform output, applies the `aws-auth` ConfigMap for worker node access, installs the AWS Load Balancer Controller with Helm, waits for the controller rollout, and deploys the sample NGINX application.
## What Gets Deployed

- EKS cluster named `demo-eks`
- Worker nodes using `eksWorkerNodeRole`
- AWS Load Balancer Controller in `kube-system`
- `aws-auth` ConfigMap for worker node access
- Sample NGINX frontend and backend application
- Kubernetes `LoadBalancer` service for public access

## Prerequisites

Make sure the playground terminal has these tools available:

```bash
aws --version
terraform version
kubectl version --client
helm version --short
jq --version
```

If Helm is missing, install it from the repository helper:

```bash
./get_helm.sh
```

## 1. Clone The Repository

```bash
git clone https://github.com/sumithksuresan/kubernetes-lab.git
cd kubernetes-lab/eks
```

## 2. Create AWS CLI Access Keys

In the KodeKloud AWS console:

1. Open **IAM**.
2. Open **Users**.
3. Select your IAM user.
4. Go to **Security credentials**.
5. Choose **Create access key**.
6. Select **Command Line Interface (CLI)** as the use case.
7. Copy the access key ID and secret access key.

Do not commit or share these keys.

## 3. Configure AWS CLI

Run:

```bash
aws configure
```

Example with sensitive values hidden:

```text
AWS Access Key ID [None]: ********************
AWS Secret Access Key [None]: ********************
Default region name [None]: us-east-1
Default output format [None]:
```

Verify the configured identity:

```bash
aws sts get-caller-identity
```

The account ID in the output should match your active KodeKloud playground account.

## 4. Check The Lab Environment

From the `eks` directory, source the environment check script:

```bash
source ./check-environment.sh
```

The script validates the expected region, default VPC, internet gateway, route table, subnets, and required local tools.

Expected final message:

```text
Good to go!
```

## 5. Initialize Terraform

```bash
terraform init
```

Example output:

```text
Initializing modules...
- use_eksClusterRole in modules/use-service-role
- create_eksClusterRole in modules/create-service-role

Initializing provider plugins...
- Finding latest version of hashicorp/tls...
- Finding latest version of hashicorp/http...
- Finding latest version of hashicorp/local...
- Finding latest version of hashicorp/aws...
- Finding latest version of hashicorp/time...

Terraform has been successfully initialized!
```

## 6. Review The Terraform Plan

```bash
terraform plan
```

The plan should include these outputs:

```text
Changes to Outputs:
  + NodeAutoScalingGroup = (known after apply)
  + NodeInstanceRole     = (known after apply)
  + NodeSecurityGroup    = (known after apply)
```

`NodeInstanceRole` is important because it is used to populate the Kubernetes `aws-auth` ConfigMap so worker nodes can join the cluster.

## 7. Apply Terraform

```bash
terraform apply
```

Approve the apply when prompted:

```text
Do you want to perform these actions?
  Terraform will perform the actions described above.

  Enter a value: yes
```

After apply completes, confirm the worker role output:

```bash
terraform output -raw NodeInstanceRole
```

Example sanitized output:

```text
arn:aws:iam::123456789012:role/eksWorkerNodeRole
```

## 8. Deploy Cluster Add-ons And The Application

Run the deployment helper:

```bash
./install-aws-load-balancer-controller.sh
```

The script performs these actions in order:

1. Reads `NodeInstanceRole` from Terraform output.
2. Updates the kubeconfig context for `demo-eks` in `us-east-1`.
3. Applies `aws-auth-cm.yaml` with the correct `NodeInstanceRole` value.
4. Installs or upgrades the AWS Load Balancer Controller with Helm.
5. Waits for the controller rollout.
6. Applies `../nginx-deployment.yaml`.

The key commands performed by the script are equivalent to:

```bash
aws eks update-kubeconfig --region us-east-1 --name demo-eks
NodeInstanceRole=$(terraform output -raw NodeInstanceRole)
sed "s|rolearn: .*|rolearn: ${NodeInstanceRole}|" aws-auth-cm.yaml | kubectl apply -f -
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=demo-eks --wait
kubectl apply -f ../nginx-deployment.yaml
```

Example sanitized output:

```text
Updating kubeconfig context for demo-eks...
Updated context arn:aws:eks:us-east-1:123456789012:cluster/demo-eks in /home/sumithk/.kube/config
Applying aws-auth ConfigMap with NodeInstanceRole: arn:aws:iam::123456789012:role/eksWorkerNodeRole
configmap/aws-auth created
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "eks" chart repository
Update Complete. Happy Helming!
Installing AWS Load Balancer Controller...
Release "aws-load-balancer-controller" has been upgraded. Happy Helming!
NAME: aws-load-balancer-controller
NAMESPACE: kube-system
STATUS: deployed
REVISION: 2
NOTES:
AWS Load Balancer controller installed!
deployment "aws-load-balancer-controller" successfully rolled out
Applying nginx deployment...
configmap/nginx-html created
deployment.apps/backend created
service/backend created
configmap/nginx-conf created
deployment.apps/nginx-fronentd created
service/nginx-service created
```

## 9. Verify Worker Node Access

Before applying `aws-auth`, the cluster may show no worker nodes:

```bash
kubectl get nodes
```

Example:

```text
No resources found
```

After `aws-auth` is applied, nodes should appear:

```bash
kubectl get nodes
```

Example sanitized output:

```text
NAME                            STATUS     ROLES    AGE   VERSION
ip-172-31-1-150.ec2.internal    NotReady   <none>   37s   v1.31.13-eks-ecaa3a6
ip-172-31-26-114.ec2.internal   NotReady   <none>   37s   v1.31.13-eks-ecaa3a6
ip-172-31-39-168.ec2.internal   Ready      <none>   32s   v1.31.13-eks-ecaa3a6
```

Wait a few minutes if some nodes are initially `NotReady`.

## 10. Verify System Pods

```bash
kubectl get pods -A
```

Example sanitized output:

```text
NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE
kube-system   aws-load-balancer-controller-xxxxxxxxxx-aaaaa   1/1     Running   0          6m
kube-system   aws-load-balancer-controller-xxxxxxxxxx-bbbbb   1/1     Running   0          6m
kube-system   aws-node-aaaaa                                 2/2     Running   0          1m
kube-system   aws-node-bbbbb                                 2/2     Running   0          1m
kube-system   aws-node-ccccc                                 2/2     Running   0          1m
kube-system   coredns-xxxxxxxxxx-aaaaa                       1/1     Running   0          10m
kube-system   coredns-xxxxxxxxxx-bbbbb                       1/1     Running   0          10m
kube-system   kube-proxy-aaaaa                               1/1     Running   0          1m
kube-system   kube-proxy-bbbbb                               1/1     Running   0          1m
kube-system   kube-proxy-ccccc                               1/1     Running   0          1m
```

## 11. Verify The Application

Check all resources:

```bash
kubectl get all -A
```

Example sanitized output after the app is deployed:

```text
NAMESPACE     NAME                                               READY   STATUS    RESTARTS   AGE
default       pod/backend-xxxxxxxxxx-aaaaa                       1/1     Running   0          2m
default       pod/backend-xxxxxxxxxx-bbbbb                       1/1     Running   0          2m
default       pod/nginx-fronentd-xxxxxxxxxx-aaaaa                1/1     Running   0          2m
default       pod/nginx-fronentd-xxxxxxxxxx-bbbbb                1/1     Running   0          2m
default       pod/nginx-fronentd-xxxxxxxxxx-ccccc                1/1     Running   0          2m
kube-system   pod/aws-load-balancer-controller-xxxxxxxxxx-aaaaa   1/1     Running   0          12m
kube-system   pod/aws-load-balancer-controller-xxxxxxxxxx-bbbbb   1/1     Running   0          12m

NAMESPACE     NAME                                        TYPE           CLUSTER-IP       EXTERNAL-IP                                      PORT(S)        AGE
default       service/backend                             ClusterIP      10.100.x.x       <none>                                           3000/TCP       2m
default       service/kubernetes                          ClusterIP      10.100.0.1       <none>                                           443/TCP        17m
default       service/nginx-service                       LoadBalancer   10.100.x.x       k8s-default-nginxser-xxxx.elb.us-east-1.amazonaws.com 80:30007/TCP  2m
kube-system   service/aws-load-balancer-webhook-service   ClusterIP      10.100.x.x       <none>                                           443/TCP        12m
```

## 12. Get The Application URL

Run:

```bash
kubectl get svc nginx-service
```

Example sanitized output:

```text
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP                                           PORT(S)        AGE
nginx-service   LoadBalancer   10.100.x.x     k8s-default-nginxser-xxxx.elb.us-east-1.amazonaws.com  80:30007/TCP   3m
```

Open the `EXTERNAL-IP` DNS name in a browser:

```text
http://k8s-default-nginxser-xxxx.elb.us-east-1.amazonaws.com
```

It may take a few minutes for the AWS load balancer DNS name to become reachable.

## Useful Commands

Update kubeconfig manually:

```bash
aws eks update-kubeconfig --region us-east-1 --name demo-eks
```

Apply `aws-auth` manually with the Terraform output:

```bash
NodeInstanceRole=$(terraform output -raw NodeInstanceRole)
sed "s|rolearn: .*|rolearn: ${NodeInstanceRole}|" aws-auth-cm.yaml | kubectl apply -f -
```

Install or upgrade the AWS Load Balancer Controller manually:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-eks \
  --wait
```

Apply the NGINX app manually:

```bash
kubectl apply -f ../nginx-deployment.yaml
```

Watch service creation:

```bash
kubectl get svc nginx-service -w
```

## Troubleshooting

### `kubectl get nodes` shows no resources

Apply `aws-auth` using the `NodeInstanceRole` Terraform output:

```bash
NodeInstanceRole=$(terraform output -raw NodeInstanceRole)
sed "s|rolearn: .*|rolearn: ${NodeInstanceRole}|" aws-auth-cm.yaml | kubectl apply -f -
```

Then wait and run:

```bash
kubectl get nodes
```

### Load balancer external address stays pending

Check controller events:

```bash
kubectl describe svc nginx-service
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

Make sure Terraform applied the IAM policy from `policy.yaml` to `eksWorkerNodeRole`:

```bash
terraform apply
```

### Wrong AWS region

This lab expects `us-east-1`:

```bash
aws configure set region us-east-1
export AWS_REGION=us-east-1
```

Then refresh kubeconfig:

```bash
aws eks update-kubeconfig --region us-east-1 --name demo-eks
```

## Cleanup

Delete the sample application:

```bash
kubectl delete -f ../nginx-deployment.yaml
```

Uninstall the AWS Load Balancer Controller:

```bash
helm uninstall aws-load-balancer-controller -n kube-system
```

Destroy Terraform resources:

```bash
terraform destroy
```