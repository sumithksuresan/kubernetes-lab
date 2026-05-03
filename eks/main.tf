####################################################################
#
#
#
####################################################################

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  region = var.aws_region
  #   default_tags {
  #     tags = {
  #       "kubernetes.io/cluster/demo-eks" = "owned"
  #     }
  #   }
}

output "NodeInstanceRole" {
  value = aws_iam_role.node_instance_role.arn
}

output "NodeSecurityGroup" {
  value = aws_security_group.node_security_group.id
}

output "NodeAutoScalingGroup" {
  value = aws_cloudformation_stack.autoscaling_group.outputs["NodeAutoScalingGroup"]
}
output "LoadBalancerControllerRoleArn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

output "VpcId" {
  value = data.aws_vpc.default_vpc.id
}
