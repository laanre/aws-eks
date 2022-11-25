terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}



resource "aws_eks_cluster" "eks_sample" {
  name     = "${var.eks_cluster}"
  role_arn = aws_iam_role.eks_demo_role.arn

  vpc_config {
    subnet_ids = ["subnet-005c38c75986b57c7", "subnet-0d87514e66d942858"]
  }
 
  depends_on = [
    aws_iam_role_policy_attachment.eks_demo_role-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_demo_role-AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.eks_sample.endpoint
}

resource "aws_iam_role" "eks_demo_role" {
  name = "eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_demo_role-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_demo_role.name
}


resource "aws_iam_role_policy_attachment" "eks_demo_role-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_demo_role.name
}

data "tls_certificate" "eks_tls" {
  url = aws_eks_cluster.eks_sample.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_openid_c" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.eks_tls.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.eks_tls.url
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_openid_c.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_openid_c.arn]
      type        = "Federated"
    }
  }
}

